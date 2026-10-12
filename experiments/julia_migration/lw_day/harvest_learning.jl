# Finite local adapter of harvest_sleep / harvest_predictability.
# No canonical assessment, T1 reconstruction, or automatic action authority.
harvest_state(actor)=D("actor"=>actor,"records"=>Any[],"seen"=>D(),"model"=>nothing,
    "admission"=>nothing,"count_first"=>nothing,"count_difference"=>nothing,
    "prediction_counts"=>D("known"=>0,"unknown"=>0),"first_known"=>nothing)

function harvest_section(move,source,now)
    food=[v for v in move["visible"] if v["appearance"]=="brown_capped_ovoid"]
    D("source"=>source,"capture_us"=>now,"complete"=>true,
      "affordance"=>any(v["distance"]<=1.25 for v in food),"count"=>length(food))
end

function harvest_observe!(h,section)
    section["complete"] || return
    if h["count_first"]===nothing
        h["count_first"]=deepcopy(section)
    elseif h["count_difference"]===nothing && section["count"]!=h["count_first"]["count"]
        h["count_difference"]=deepcopy(section)
    end
end

function harvest_result!(h,actor,operation,before,status,executed,after;accepted=true)
    check(accepted && actor==h["actor"],"harvest_acceptance")
    check(before["capture_us"]<executed<=after["capture_us"],"harvest_clock")
    check(status in ("picked_up","not_found"),"harvest_result")
    r=D("operation_id"=>operation,"agent_id"=>actor,"before"=>deepcopy(before),
        "after"=>deepcopy(after),"executed_us"=>executed,"acquired"=>status=="picked_up",
        "affordance_persists"=>after["affordance"])
    if haskey(h["seen"],operation)
        check(h["seen"][operation]==r,"harvest_conflict");return false
    end
    # Earliest six operations are the fixed learning window, never a successful subset.
    length(h["records"])>=6 && return false
    h["seen"][operation]=r;push!(h["records"],r);true
end

function freeze_harvest!(h,cycle,now)
    haskey(cycle,"harvest_frozen_us") && return
    cycle["harvest_frozen_us"]=now
    cycle["records"]=deepcopy([r for r in h["records"] if r["after"]["capture_us"]<=now])
    cycle["count_evidence"]=deepcopy([h["count_first"],h["count_difference"]])
end

function consolidate_harvest!(h,cycle,executed)
    rs=cycle["records"];reason=nothing
    status=if get(h,"invalidated",false)
        "MODEL_INVALIDATED"
    elseif h["model"]!==nothing
        "MODEL_ALREADY_PRESENT"
    elseif length(rs)<5
        "INSUFFICIENT_EVIDENCE"
    elseif h["admission"]!==nothing && h["admission"]["status"]=="REJECT"
        "PREVIOUSLY_REJECTED"
    elseif !all(r["before"]["complete"] && r["after"]["complete"] for r in rs[1:5])
        reason="incomplete_observation";"DEFER"
    elseif !all(r["before"]["affordance"] && r["acquired"] && r["affordance_persists"] for r in rs[1:5])
        reason="held_out_or_formation_counterexample";"REJECT"
    elseif any(x===nothing for x in cycle["count_evidence"])
        reason="actual_count_difference_unavailable";"DEFER"
    else
        h["model"]=D("model_ref"=>"local-harvest:"*h["actor"]*":"*string(cycle["day"]),
            "appearance"=>"brown_capped_ovoid","formation"=>[r["operation_id"] for r in rs[1:3]],
            "validation"=>[r["operation_id"] for r in rs[4:5]],"formed_us"=>executed,
            "prediction"=>D("acquired"=>1,"affordance_persists"=>1),
            "authority"=>"finite local prediction; no canonical T1 or action override")
        "LOCAL_ADOPTED"
    end
    result=D("status"=>status,"reason"=>reason,"model_ref"=>h["model"]===nothing ? nothing : h["model"]["model_ref"])
    if !(status in ("PREVIOUSLY_REJECTED","MODEL_ALREADY_PRESENT","MODEL_INVALIDATED"))
        h["admission"]=deepcopy(result)
    end
    cycle["relation_review"]=D("status"=>"harvest_only","general_cross_action_review"=>"unported")
    cycle["result"]=result
end

function harvest_predict(h,section)
    known=!get(h,"invalidated",false) && h["model"]!==nothing && section["complete"] && section["affordance"] && section["capture_us"]>=h["model"]["formed_us"]
    D("status"=>known ? "known" : "unknown","values"=>known ? deepcopy(h["model"]["prediction"]) : nothing,
      "model_ref"=>h["model"]===nothing ? nothing : h["model"]["model_ref"],"source"=>section["source"])
end
