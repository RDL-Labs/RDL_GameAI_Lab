# Fixed operational profiles over the SAME finite observations; no new sensing.
function rho_map(ground,obstacles,profile)
    profile in ("coarse","fine") || error("invalid rho_map profile: $profile")
    ground["source"]["observation"]==obstacles["source"] || error("rho_map source mismatch")
    map=local_structures(ground,obstacles;max_link=profile=="coarse" ? 2.5 : 1.0)
    map["rho"]=profile
    map["coverage"]=obstacles["coverage"]
    map["output_limited"]=obstacles["output_limited"]
    map
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
    for c in candidates
        c["action"] in ("walk","run") || continue
        angle=get(c,"steering_angle",Float64(ANGLES[c["direction"]+1]))
        depth_support=maximum((min(1.,o.contrast/4)*max(0.,cosd(angle-o.angle))^4 for o in openings);init=0.)
        field=rho_potential(map,(.5sind(angle),.5cosd(angle)),angle)
        c["observation_log_prior"]=2.5depth_support-min(2.,2field.repulsion)
        c["affordance_source"]=map["source"]["observation"]
    end
end

# Scalar cost at an actor-relative candidate endpoint, not Core E or H.
function rho_potential(map,point,heading;clearance=2.,water_weight=.35,road_weight=.15)
    x,z=point
    attraction=-(x*sind(heading)+z*cosd(heading))
    repulsion=0.;road=0.
    for g in map["groups"]
        points=g["points"];isempty(points) && continue
        if g["kind"] in ("obstacle","water")
            d=minimum(hypot(x-p[1],z-p[2]) for p in points)
            weight=g["kind"]=="water" ? water_weight : 1.
            repulsion+=weight*clearance*max(0.,1-d/clearance)^3
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
    best_angle=angle;best=nothing
    for offset in offsets
        candidate=angle+offset
        value=rho_potential(map,(span*sind(candidate),span*cosd(candidate)),angle;clearance=clearance)
        if best===nothing || value.total<best.total-1e-12
            best=value;best_angle=candidate
        end
    end
    (angle=best_angle,combined=(cosd(best_angle),sind(best_angle)),
        groups=count(g->g["kind"] in ("obstacle","water"),map["groups"]),potential=best)
end
