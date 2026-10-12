# Local approach-to-test appraisal; never expands harvest prediction to far food.
function harvest_field(candidates,move,h,actor,now;enabled=false,complete=true)
    check(h["actor"]==actor,"harvest_field_actor")
    out=[copy(c) for c in candidates]
    trace=D("status"=>"no_model","applied"=>false,"contributions"=>Any[],
        "model_ref"=>nothing,"gain"=>0.5,"purpose"=>"approach-to-test")
    model=h["model"];model===nothing && return out,trace
    trace["model_ref"]=model["model_ref"]
    check(h["admission"]["status"]=="LOCAL_ADOPTED","harvest_field_admission")
    if now<model["formed_us"] || !complete
        trace["status"]="not_comparable";return out,trace
    end
    visible=[v for v in move["visible"] if v["appearance"]==model["appearance"]]
    for c in out
        c["action"]=="walk" || continue
        index=c["direction"]
        any(r["ref"]==string(index) && r["cost"]!==nothing for r in move["energy"]["rows"]) || continue
        angle=deg2rad(Float64(ANGLES[index+1]))
        # Julia's five-direction scaffold has no normalized terrain source field.
        # Bounded angular alignment is the declared adapter, not exact Python cost parity.
        value=min(0.5,sum((0.5*max(0.,cos(atan(v["right"],v["forward"])-angle)) for v in visible);init=0.))
        value>0 || continue
        push!(trace["contributions"],D("method"=>c["method"],"value"=>value))
        enabled && (c["priority"]+=value)
    end
    trace["status"]=isempty(trace["contributions"]) ? "no_matching_feasible_candidate" : enabled ? "applied" : "shadow"
    trace["applied"]=trace["status"]=="applied"
    out,trace
end
