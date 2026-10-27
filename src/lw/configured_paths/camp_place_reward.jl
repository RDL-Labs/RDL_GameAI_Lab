# One finite, explicitly configured completion reward; not per-step pleasure.
function configured_camp_place_rest!(place,landmark,loop,plan,status,at_home,now)
    place["complete"] && return
    valid=landmark["tour_completed"] && landmark["learned"] && at_home &&
        get(plan,"configured_place_rest",false) && plan["action"]=="rest" && status=="performed"
    if !valid;place["rest_ticks"]=0;place["last_rest_us"]=nothing;return;end
    last=place["last_rest_us"]
    place["rest_ticks"]=last!==nothing && now==last+1_000_000 ? place["rest_ticks"]+1 : 1
    place["last_rest_us"]=now
    place["rest_ticks"]>=60 && mb_place_finish!(place,loop,landmark["signature"],now+1_000_000)
end
