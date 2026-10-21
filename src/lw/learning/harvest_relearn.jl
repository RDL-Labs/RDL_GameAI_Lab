# One explicit replacement schema: nearby acquisition, without persistence claim.
# This is finite relearning, not autonomous relation-language invention.
function replacement_result!(h,actor,op,before,status,executed,after;accepted=true,pose=true)
    check(accepted && actor==h["actor"],"replacement_acceptance")
    get(h,"relearn_enabled",false) && get(h,"invalidated",false) && !get(h,"replacement_used",false) || return false
    check(before["capture_us"]<executed<=after["capture_us"],"replacement_clock")
    check(status in ("picked_up","not_found"),"replacement_result")
    inv=h["invalidation"]
    # Only persistence-only counterexamples license this declared narrowing.
    get(inv["difference"],"acquired",-1)==0 && get(inv["difference"],"affordance_persists",0)!=0 || return false
    before["capture_us"]>=inv["compared_us"] || return false
    op in vcat(h["model"]["formation"],h["model"]["validation"],[inv["operation"]]) && return false
    r=D("operation_id"=>op,"agent_id"=>actor,"before"=>deepcopy(before),"after"=>deepcopy(after),
        "executed_us"=>executed,"acquired"=>status=="picked_up","pose"=>pose)
    rows=get!(h,"replacement_records",Any[])
    prior=findfirst(x->x["operation_id"]==op,rows)
    if prior!==nothing
        check(rows[prior]==r,"replacement_conflict");return false
    end
    length(rows)>=6 && return false
    push!(rows,r);true
end

function consolidate_replacement!(h,c,now)
    rows=get(c,"replacement_records",Any[])
    result=if get(h,"replacement_used",false)
        "MODEL_INVALIDATED"
    elseif length(rows)<5
        "REPLACEMENT_INSUFFICIENT"
    elseif !all(r["before"]["complete"] && r["after"]["complete"] && r["pose"] for r in rows[1:5])
        "REPLACEMENT_DEFER"
    elseif !all(r["before"]["affordance"] && r["acquired"] for r in rows[1:5])
        "REPLACEMENT_REJECT"
    else
        old=deepcopy(h["model"])
        h["previous_model"]=old;h["previous_admission"]=deepcopy(h["admission"])
        h["model"]=D("model_ref"=>"local-harvest-narrow:"*h["actor"]*":"*string(c["day"]),
            "appearance"=>old["appearance"],"formed_us"=>now,"prediction"=>D("acquired"=>1),
            "formation"=>[r["operation_id"] for r in rows[1:3]],"validation"=>[r["operation_id"] for r in rows[4:5]],
            "replaces"=>old["model_ref"],"authority"=>"provided acquisition-only schema; finite local inspection, not canonical T1")
        h["admission"]=D("status"=>"LOCAL_ADOPTED","model_ref"=>h["model"]["model_ref"])
        h["invalidated"]=false;h["replacement_used"]=true
        "LOCAL_REPLACED"
    end
    c["relation_review"]=D("status"=>"replacement_harvest_only","general_cross_action_review"=>"unported")
    c["result"]=D("status"=>result,"model_ref"=>h["model"]["model_ref"],"reason"=>nothing)
end
