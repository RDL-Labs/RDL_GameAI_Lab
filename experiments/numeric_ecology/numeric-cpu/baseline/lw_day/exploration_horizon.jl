# GameAI-local cross-day pressure, ported from runtime/exploration_horizon.py.
horizon_state(actor)=D("actor"=>actor,"H"=>0,"threshold"=>2,"count"=>0,"charged"=>nothing,"events"=>Any[],"selections"=>0)
function horizon_result!(s,actor,op,phase,status,acquired;linked=true)
    actor==s["actor"] || error("horizon_binding")
    (!linked || op==s["charged"]) && return false
    s["charged"]=op;before=s["H"];reason=nothing
    if acquired
        s["H"]=0;s["count"]=0;reason="acquired"
    elseif phase=="exploration" && status in ("moved","turned","waited","blocked")
        s["count"]+=1
        if s["count"]==8
            s["H"]=min(32,before+1);s["count"]=0
            reason="eight_exploration_effects_without_acquisition"
        end
    end
    if reason!==nothing
        push!(s["events"],D("source"=>op,"H_before"=>before,"H_after"=>s["H"],"E"=>acquired ? 0 : 1,"reason"=>reason))
        length(s["events"])>16 && popfirst!(s["events"])
    end
    true
end
function horizon_candidates(s,fan,move)
    s["H"]>=s["threshold"] || return Any[]
    safe=[Int(ANGLES[i]) for i in 1:5 if move["energy"]["rows"][i]["cost"]!==nothing]
    out=Dict{Int,Any}();pressure=min(4.,s["H"]/s["threshold"])
    for (i,f) in enumerate(fan["features"])
        f["range_band"] in ("mid","far") || continue
        lo,hi=f["azimuth"];hi-lo<=45 && !isempty(safe) || continue
        center=(lo+hi)/2;angle=safe[argmin(abs.(safe .- center))]
        abs(angle-center)<=22.5 || continue
        score=2+pressure*(f["range_band"]=="far" ? 1. : .35)
        if !haskey(out,angle) || score>out[angle]["priority"]
            out[angle]=D("method"=>"horizon_$angle","action"=>"walk","direction"=>findfirst(==(angle),ANGLES)-1,
                "priority"=>score,"question"=>"movement_progress","horizon_source"=>fan["source"],"feature_index"=>i)
        end
    end
    [out[a] for a in sort(collect(keys(out)))]
end
