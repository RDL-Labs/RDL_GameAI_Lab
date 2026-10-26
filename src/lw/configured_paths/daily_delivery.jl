# Experimental daily objective, deliberately separate from learned MB goals.
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
