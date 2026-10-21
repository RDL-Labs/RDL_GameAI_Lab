const DAY=17_280_000_000
const REST=2_880_000_000
function sleeper(day,rest=0)
    D("sleep"=>D("cycle"=>D("day"=>day,"status"=>"pending","rest_us"=>rest,"records"=>Any[],
        "source"=>"night","result"=>nothing,"relation_materials"=>D("records"=>Any[],"window"=>D()),"relation_review"=>nothing),"completed"=>Any[]))
end
function receipt!(learning,now;phase="night",status="waited",pose=true,kind="wait",accepted=true,on_complete=nothing)
    check(accepted,"sleep_result_not_accepted")
    c=learning["sleep"]["cycle"]
    c["status"]!="pending" && return false
    executed=now+1_000_000
    executed<=get(c,"last_rest_executed_us",-1) && return false
    c["day"]!=div(now,DAY) && return false
    valid=phase=="night" && kind=="wait" && status=="waited" && pose && now<executed<=(c["day"]+1)*DAY
    c["last_rest_operation"]="op:$now";c["last_rest_executed_us"]=executed
    c["rest_us"]=valid ? c["rest_us"]+1_000_000 : 0
    if c["rest_us"]>=REST
        if on_complete!==nothing
            on_complete(c,executed)
            c["status"]="completed";c["completed_us"]=executed
            return true
        end
        # Explicit empty-harvest-material branch, not general relation inspection.
        check(isempty(c["records"]) && isempty(c["relation_materials"]["records"]),"unported_sleep_material")
        c["relation_review"]=D("rule"=>"cross-action-sleep-review-v1","status"=>"insufficient_records",
            "window"=>D(),"records"=>Any[],"profiles"=>Any[],"pair_results"=>Any[],"candidate_admission"=>"none",
            "authority"=>"matches/differences/missing only; no causal inference, support amplification or M_B update")
        c["status"]="completed";c["result"]=D("status"=>"INSUFFICIENT_EVIDENCE","reason"=>nothing,"model_ref"=>nothing)
        c["completed_us"]=executed
    end
    true
end
