# Experimental daily objective, deliberately separate from learned MB goals.
# 局所観測用の固定設定: isolate planning behavior, not autonomous purpose formation.
configured_daily_delivery_state()=D("day"=>-1,"completed"=>false,"known_stock"=>0,
    "completions"=>0,"stay_requests"=>0,"food_exceptions"=>0,"records"=>Any[])
function configured_daily_delivery_day!(s,now,day_us)
    day=div(now,day_us)
    if s["day"]!=day
        s["day"]=day;s["completed"]=false
    end
end
function configured_daily_delivery_deposit!(s,amount,now,day_us)
    configured_daily_delivery_day!(s,now,day_us)
    amount>0 || return
    if !s["completed"]
        s["completed"]=true;s["completions"]+=1
        push!(s["records"],D("day"=>s["day"],"us"=>now,"delivered"=>amount))
        length(s["records"])>32 && popfirst!(s["records"])
    end
end
function configured_daily_delivery_request!(s,returning,replenishing,inventory,at_home,visible_stock,now,day_us)
    configured_daily_delivery_day!(s,now,day_us)
    at_home && (s["known_stock"]=visible_stock)
    s["completed"] || return returning
    if replenishing && inventory==0 && s["known_stock"]==0
        s["food_exceptions"]+=1
        return returning
    end
    s["stay_requests"]+=1
    true # Existing home navigation/rest; safety and eating keep their priority.
end
# Scenario bootstrap preferences, not learned MBs or a universal biological rule.
function configured_daily_plan_scores(confidence,inventory,reserve,replenishing,roundtrip_penalty,return_penalty,return_hint)
    food=3.0+log1p(confidence)-roundtrip_penalty-log1p(inventory)
    replenishing && (food+=2log1p(max(0.,60-reserve)))
    home=roundtrip_penalty+4log1p(inventory)-return_penalty+Float64(return_hint)
    food,home
end
configured_daily_plan_stay(replenishing)=!replenishing
