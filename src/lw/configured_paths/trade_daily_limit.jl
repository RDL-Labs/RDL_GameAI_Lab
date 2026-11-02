# Temporary configured rule, shared across food and object trade initiation.
function trade_start_available(state,now,day_us)
    q=get(state,"trade_daily_start",nothing)
    q===nothing || q["day"]!=div(now,day_us) || q["used"]==0
end
function trade_start_record!(state,action,status,now,day_us,operation)
    action in ("item_offer","trade_offer") && status=="offered" || return false
    q=get!(state,"trade_daily_start") do
        D("day"=>-1,"used"=>0,"total"=>0,"operation"=>nothing)
    end
    q["operation"]==operation && return false
    day=div(now,day_us)
    q["day"]!=day && (q["day"]=day;q["used"]=0)
    q["used"]+=1;q["total"]+=1;q["operation"]=operation
    true
end
