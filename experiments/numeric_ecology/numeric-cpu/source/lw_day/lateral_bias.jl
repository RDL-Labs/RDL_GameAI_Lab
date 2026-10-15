# Exact finite gate from runtime/composed_lateral_bias.py.
# Consumes appraised directional components, never hidden World geometry.
function composed_lateral_bias(terrain,side)
    side in ("left","right") || error("lateral_side")
    out=deepcopy(terrain); samples=out["directional_samples"]
    rows=Dict(r["direction_deg"]=>r for r in samples); eligible=Set{Int}()
    if out["status"]=="complete" && !(0 in out["minimum_directions"])
        for angle in (45,90)
            left,right=rows[-angle],rows[angle]
            left["status"]=="scored" && right["status"]=="scored" || continue
            any(a->a in out["minimum_directions"],(-angle,angle)) || continue
            any(k->abs(get(left,k,0)-get(right,k,0))>.10+1e-9,
                ("physical","food","obstacle","model_field_cost","total")) && continue
            union!(eligible,(-angle,angle))
        end
    end
    prior=deepcopy(out["minimum_directions"])
    for row in samples
        angle=row["direction_deg"]
        cost=angle in eligible ? ((angle<0)==(side=="left") ? -.05 : .05) : 0.
        row["lateral_cost"]=row["status"]=="scored" ? cost : nothing
        row["status"]=="scored" && (row["total"]+=cost)
    end
    if !isempty(eligible)
        minimum_value=minimum(r["total"] for r in samples if r["status"]=="scored")
        out["minimum_height"]=minimum_value
        out["minimum_directions"]=[r["direction_deg"] for r in samples if r["status"]=="scored" && abs(r["total"]-minimum_value)<=1e-9]
    end
    out["lateral"]=Dict("rule"=>"composed-lateral-near-tie-v1","side"=>side,"height"=>.05,
        "width"=>.10,"eligible"=>sort(collect(eligible)),"applied"=>!isempty(eligible),
        "before_minima"=>prior,"after_minima"=>out["minimum_directions"])
    out
end

# Seven finite rays, matching LW World.packet's obstacle-point observation.
function lateral_obstacles(objects,position,yaw,source)
    items=Any[]
    for (i,angle) in enumerate(-90:30:90)
        sn,cs=sincos(deg2rad(yaw+angle));best=Inf
        for o in objects
            o.height>=1 || continue
            d=RDLMigrationProbe.ray_hit(position,(sn,cs),RDLMigrationProbe.Circle(o.x,o.z,o.radius))
            d!==nothing && d<=12 && (best=min(best,d))
        end
        isfinite(best) && push!(items,Dict("ref"=>"$source:ray:$(i-1)",
            "forward"=>max(0.,best*cosd(angle)),"right"=>best*sind(angle)))
    end
    Dict("source"=>source,"coverage"=>"complete","output_limited"=>false,"items"=>items)
end

function lateral_terrain(move,obstacles;model_cost=Dict{Int,Float64}())
    ground=move["movement_surface"]["ground"]
    complete=move["food_coverage"]=="complete" && ground["coverage"]=="complete" &&
        !ground["output_limited"] && obstacles["coverage"]=="complete" && !obstacles["output_limited"]
    foods=[f for f in move["visible"] if f["appearance"]=="brown_capped_ovoid"]
    rows=Any[]
    for surface in ground["samples"]
        angle=surface["direction_deg"];f,r=cosd(angle),sind(angle)
        physical=nothing;food=nothing;obstacle=nothing;total=nothing;status="not_evaluated"
        mc=get(model_cost,angle,0.)
        if complete
            food=sum(sort([-4*max(0.,1-hypot(f-x["forward"],r-x["right"])/12)/max(1,length(foods)) for x in foods]);init=0.)
            parts=Float64[]
            for x in obstacles["items"]
                t=clamp(x["forward"]*f+x["right"]*r,0.,1.)
                push!(parts,6*max(0.,1-hypot(x["forward"]-t*f,x["right"]-t*r)/6)^2)
            end
            obstacle=min(12.,sum(sort(parts);init=0.))
            scored=surface["status"]=="sampled" && abs(surface["height_delta"])<=1
            status=scored ? "scored" : "excluded_by_observation"
            if scored
                physical=2*abs(surface["height_delta"]);total=physical+food+obstacle+mc
            end
        end
        push!(rows,Dict("direction_deg"=>angle,"status"=>status,"physical"=>physical,
            "food"=>food,"obstacle"=>obstacle,"model_field_cost"=>mc,"total"=>total))
    end
    scored=[x for x in rows if x["status"]=="scored"]
    low=isempty(scored) ? nothing : minimum(x["total"] for x in scored)
    Dict("status"=>!complete ? "acquisition_incomplete" : isempty(scored) ? "no_supported_direction" : "complete",
        "directional_samples"=>rows,"minimum_height"=>low,
        "minimum_directions"=>complete ? [x["direction_deg"] for x in scored if abs(x["total"]-low)<=1e-9] : nothing)
end

function project_lateral!(candidates,move,obstacles,side,field_trace)
    costs=Dict{Int,Float64}()
    if field_trace!==nothing && field_trace["applied"]
        for c in candidates
            c["action"]=="walk" || continue
            terms=[x["value"] for x in field_trace["contributions"] if x["method"]==c["method"]]
            isempty(terms) || (costs[ANGLES[c["direction"]+1]]=-first(terms))
        end
    end
    terrain=composed_lateral_bias(lateral_terrain(move,obstacles;model_cost=costs),side)
    for c in candidates
        c["action"]=="walk" || continue
        row=terrain["directional_samples"][c["direction"]+1]
        row["lateral_cost"]===nothing || (c["priority"]-=row["lateral_cost"])
    end
    terrain["lateral"]
end
