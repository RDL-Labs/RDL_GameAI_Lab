# Fixed operational profiles over the SAME finite observations; no new sensing.
function rho_map(ground,obstacles,profile;boxes=false)
    profile in ("coarse","fine") || error("invalid rho_map profile: $profile")
    ground["source"]["observation"]==obstacles["source"] || error("rho_map source mismatch")
    compact=boxes && profile=="coarse"
    map=local_structures(ground,obstacles;max_link=profile=="coarse" ? 2.5 : 1.0,compact)
    map["boundary_representation"]=compact ? "observed_group_boxes" : "sample_points"
    if compact
        for group in map["groups"]
            group["kind"] in ("obstacle","water") || continue
            points=group["points"]
            group["observed_bounds"]=(minimum(p[1] for p in points),maximum(p[1] for p in points),
                minimum(p[2] for p in points),maximum(p[2] for p in points))
        end
    end
    map["rho"]=profile
    map["coverage"]=obstacles["coverage"]
    map["output_limited"]=obstacles["output_limited"]
    map
end

# Cognitive approximation only: bounds enclose observed samples, not world geometry.
# Zero inside is a conservative solid approximation; fine rho restores sampled gaps.
rho_box_distance(bounds,point)=hypot(max(bounds[1]-point[1],0.,point[1]-bounds[2]),
    max(bounds[3]-point[2],0.,point[2]-bounds[4]))

# Nearness alone does not request detail. Reuse existing confirmation state and
# executed movement evidence; no new H threshold or forced movement is introduced.
function rho_box_profile(estimate,receipt;explicit_fine=false)
    checking=get(estimate,"checking",false)
    moving=receipt!==nothing && get(receipt,"action","") in ("walk","run")
    blocked=moving && (get(receipt,"status","")!="performed" ||
        iszero(hypot(receipt["forward"],receipt["right"])))
    confirming=receipt!==nothing && get(receipt,"action","")=="scan"
    explicit_fine || checking || blocked || confirming ? "fine" : "coarse"
end

function rho_observed_map!(state,ground,obstacles,profile;boxes=false)
    previous=get(state,"observation",nothing)
    representation=boxes && profile=="coarse" ? "observed_group_boxes" : "sample_points"
    if previous!==nothing && previous["source"]==ground["source"] &&
       get(previous,"rho",nothing)==profile && get(previous,"boundary_representation",nothing)==representation
        return previous
    end
    rho_map(ground,obstacles,profile;boxes)
end

# A sampled depth discontinuity is a passage hypothesis, not a known exit.
# Require a clear ray bounded by observed hits; unknown/edge sectors never qualify.
function rho_openings(map)
    map["coverage"]=="complete" && !map["output_limited"] || return Any[]
    rays=[n for n in map["nodes"] if n["layer"]=="obstacle"]
    out=Any[];i=2
    while i<length(rays)
        n=rays[i]
        if n["status"]!="sampled" || n["kind"]!="clear_ray"
            i+=1;continue
        end
        first_clear=i
        while i<=length(rays) && rays[i]["status"]=="sampled" && rays[i]["kind"]=="clear_ray"
            i+=1
        end
        i>length(rays) && break
        left,right=rays[first_clear-1],rays[i]
        all(n->n["status"]=="sampled" && n["kind"]=="obstacle",(left,right)) || continue
        # Retain an actually sampled ray, never interpolate a hidden opening.
        middle=div(first_clear+i-1,2);point=rays[middle]["point"]
        depth=hypot(point...);contrast=depth-max(hypot(left["point"]...),hypot(right["point"]...))
        contrast>=1. || continue
        push!(out,(angle=rad2deg(atan(point[1],point[2])),depth=depth,
            contrast=contrast,samples=[left["sample"],rays[middle]["sample"],right["sample"]]))
    end
    out
end

function rho_opening_candidates(map,move)
    out=Any[]
    for opening in rho_openings(map)
        safe=[i for i in 1:5 if move["energy"]["rows"][i]["cost"]!==nothing && abs(ANGLES[i]-opening.angle)<=22.5]
        isempty(safe) && continue
        i=first(sort(safe,by=i->abs(ANGLES[i]-opening.angle)))
        # The ID is a bounded bearing class; no permanent doorway identity is implied.
        bin=round(Int,opening.angle/15)
        push!(out,D("method"=>"opening:$bin","action"=>"walk","direction"=>i-1,
            "steering_angle"=>opening.angle,"priority"=>3.,"question"=>"target_observed",
            "opening_samples"=>opening.samples,"opening_source"=>map["source"]["observation"]))
    end
    out
end

# Current geometric evidence remains informative even when learned alternatives
# are being broadened by parent H. This is not reward, memory, or passability.
function project_rho_affordance!(candidates,map)
    map["coverage"]=="complete" && !map["output_limited"] || return
    openings=rho_openings(map)
    local_field=rho_local_field(map;span=.5)
    for c in candidates
        c["action"] in ("walk","run") || continue
        angle=get(c,"steering_angle",Float64(ANGLES[c["direction"]+1]))
        depth_support=maximum((min(1.,o.contrast/4)*max(0.,cosd(angle-o.angle))^4 for o in openings);init=0.)
        field=rho_local_potential(local_field,(.5sind(angle),.5cosd(angle)),angle)
        c["observation_log_prior"]=2.5depth_support-min(2.,2field.repulsion)
        c["affordance_source"]=map["source"]["observation"]
    end
end

# Scalar cost at an actor-relative candidate endpoint, not Core E or H.
# Fine interpretation concentrates the field near observed boundary samples.
# Preserve load/damage/running additions and the field amplitude; physical
# clearance (body radius .2) is still checked independently by the world.
function rho_boundary_range(map,clearance)
    isfinite(clearance) && clearance>0 || error("invalid rho clearance")
    get(map,"rho","coarse")=="fine" ? max(.35,clearance-1.5) : clearance
end
function rho_potential(map,point,heading;clearance=2.,water_weight=.35,road_weight=.15)
    boundary_range=rho_boundary_range(map,clearance)
    x,z=point
    attraction=-(x*sind(heading)+z*cosd(heading))
    repulsion=0.;road=0.
    for g in map["groups"]
        points=g["points"];isempty(points) && continue
        if g["kind"] in ("obstacle","water")
            d=haskey(g,"observed_bounds") ? rho_box_distance(g["observed_bounds"],point) : minimum(hypot(x-p[1],z-p[2]) for p in points)
            weight=g["kind"]=="water" ? water_weight : 1.
            repulsion+=weight*clearance*max(0.,1-d/boundary_range)^3
        elseif g["kind"]=="worn_ground" && length(points)>=3
            # Only elongated observed groups supply an undirected road axis.
            mx=sum(p[1] for p in points)/length(points);mz=sum(p[2] for p in points)/length(points)
            xx=sum((p[1]-mx)^2 for p in points);zz=sum((p[2]-mz)^2 for p in points)
            xz=sum((p[1]-mx)*(p[2]-mz) for p in points)
            disc=hypot(xx-zz,2xz);major=(xx+zz+disc)/2;minor=(xx+zz-disc)/2
            major>1e-8 && major>=4max(minor,0.) || continue
            theta=.5atan(2xz,xx-zz);ux,uz=cos(theta),sin(theta)
            # Local proximity only. No target, extension, or passability is inferred.
            proximity=max(0.,1-minimum(hypot(p...) for p in points)/4)
            road=max(road,road_weight*proximity*abs(x*ux+z*uz))
        end
    end
    (total=attraction+repulsion-road,attraction=attraction,repulsion=repulsion,road=road)
end

function rho_descent(angle,map;clearance=2.,span=.5)
    map["coverage"]=="complete" && !map["output_limited"] || return nothing
    # Deterministic local refinement of an upstream probabilistically chosen method.
    offsets=(0.,-11.25,11.25,-22.5,22.5,-33.75,33.75,-45.,45.)
    local_field=rho_local_field(map;clearance=clearance,span=span)
    before=-rho_local_potential(local_field,(0.,0.),angle).total
    selected=relational_best(offsets) do offset
        candidate=angle+offset
        value=rho_local_potential(local_field,(span*sind(candidate),span*cosd(candidate)),angle)
        merge(relational_transition(before,-value.total),(potential=value,))
    end
    best_angle=angle+selected.candidate;best=selected.field.potential
    (angle=best_angle,combined=(cosd(best_angle),sind(best_angle)),
        groups=count(g->g["kind"] in ("obstacle","water"),map["groups"]),potential=best)
end

# Prepared once per candidate batch, never persisted across observations or actors.
# A point beyond span + support cannot contribute to any endpoint in this batch.
function rho_local_field(map;clearance=2.,span=.5,water_weight=.35,road_weight=.15)
    range=rho_boundary_range(map,clearance)
    radius=abs(span)+range
    radius+=16eps(max(1.,radius)) # Conservative floating-point boundary inclusion.
    surfaces=Vector{Tuple{Float64,Vector{Tuple{Float64,Float64}}}}()
    boxes=Tuple{Float64,NTuple{4,Float64}}[]
    roads=Tuple{Float64,Float64,Float64}[]
    for g in map["groups"]
        points=g["points"];isempty(points) && continue
        if g["kind"] in ("obstacle","water")
            if haskey(g,"observed_bounds")
                bounds=NTuple{4,Float64}(g["observed_bounds"])
                rho_box_distance(bounds,(0.,0.))<=radius && push!(boxes,(g["kind"]=="water" ? Float64(water_weight) : 1.,bounds))
                continue
            end
            local_points=Tuple{Float64,Float64}[(p[1],p[2]) for p in points if hypot(p...)<=radius]
            isempty(local_points) || push!(surfaces,(g["kind"]=="water" ? Float64(water_weight) : 1.,local_points))
        elseif g["kind"]=="worn_ground" && length(points)>=3
            # Keep ALL road samples: distant points can determine the local axis.
            mx=sum(p[1] for p in points)/length(points);mz=sum(p[2] for p in points)/length(points)
            xx=sum((p[1]-mx)^2 for p in points);zz=sum((p[2]-mz)^2 for p in points)
            xz=sum((p[1]-mx)*(p[2]-mz) for p in points)
            disc=hypot(xx-zz,2xz);major=(xx+zz+disc)/2;minor=(xx+zz-disc)/2
            major>1e-8 && major>=4max(minor,0.) || continue
            theta=.5atan(2xz,xx-zz);ux,uz=cos(theta),sin(theta)
            proximity=max(0.,1-minimum(hypot(p...) for p in points)/4)
            push!(roads,(Float64(road_weight)*proximity,ux,uz))
        end
    end
    (surfaces=surfaces,boxes=boxes,roads=roads,clearance=Float64(clearance),range=range)
end
function rho_local_potential(field,point,heading)
    x,z=point;attraction=-(x*sind(heading)+z*cosd(heading));repulsion=0.;road=0.
    for (weight,points) in field.surfaces
        d=minimum(hypot(x-p[1],z-p[2]) for p in points)
        repulsion+=weight*field.clearance*max(0.,1-d/field.range)^3
    end
    for (weight,bounds) in field.boxes
        d=rho_box_distance(bounds,point)
        repulsion+=weight*field.clearance*max(0.,1-d/field.range)^3
    end
    for (gain,ux,uz) in field.roads
        road=max(road,gain*abs(x*ux+z*uz))
    end
    (total=attraction+repulsion-road,attraction=attraction,repulsion=repulsion,road=road)
end
