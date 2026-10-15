# Execution-bound comparison, adapted from multi_resource_exploration._advance.
function review_harvest!(h,actor,op,prediction,before,status,executed,after;accepted=true,pose=true)
    check(accepted && actor==h["actor"],"harvest_review_actor_or_acceptance")
    prediction["status"]=="known" || return false
    check(h["model"]!==nothing && prediction["model_ref"]==h["model"]["model_ref"],"harvest_review_model")
    check(prediction["source"]==before["source"],"harvest_review_source")
    check(before["capture_us"]<executed<=after["capture_us"],"harvest_review_clock")
    request=D("operation"=>op,"prediction"=>deepcopy(prediction),"before"=>deepcopy(before),
        "status"=>status,"executed"=>executed,"after"=>deepcopy(after),"pose"=>pose)
    last=get(h,"review_receipt",nothing)
    if last!==nothing
        if last["operation"]==op
            check(last==request,"harvest_review_conflict");return false
        end
        check(executed>last["executed"],"harvest_review_old_result")
    end
    comparable=pose && before["complete"] && after["complete"] && status in ("picked_up","not_found")
    observed=comparable ? D("acquired"=>Int(status=="picked_up"),"affordance_persists"=>Int(after["affordance"])) : nothing
    delta=comparable ? D(k=>observed[k]-v for (k,v) in prediction["values"]) : nothing
    verdict=!comparable ? "defer" : any(v!=0 for v in values(delta)) ? "difference" : "confirmed"
    row=D("operation"=>op,"source"=>before["source"],"later"=>after["source"],"model_ref"=>prediction["model_ref"],
        "F"=>deepcopy(prediction["values"]),"F_prime"=>observed,"difference"=>delta,"status"=>verdict,
        "executed_us"=>executed,"compared_us"=>after["capture_us"])
    rows=get!(h,"comparisons",Any[]);push!(rows,row);length(rows)>32 && popfirst!(rows)
    totals=get!(h,"comparison_counts",D("confirmed"=>0,"difference"=>0,"defer"=>0));totals[verdict]+=1
    h["review_receipt"]=request
    if verdict=="difference" && !get(h,"invalidated",false)
        h["invalidated"]=true;h["invalidation"]=deepcopy(row)
        history=get!(h,"invalidations",Any[]);push!(history,deepcopy(row));length(history)>2 && popfirst!(history)
    end
    true
end
