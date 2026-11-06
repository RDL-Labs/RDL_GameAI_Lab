# Declared experimental behavior: stop cognition after a completed provision goal until night.
# Not learned attention, an embedded MB, or a biological sleep model.
configured_post_return_idle_state()=D("active"=>false,"ticks"=>0,"entries"=>0,"records"=>Any[])
function configured_post_return_idle!(s,now,day_us,night_us;pending=false,observing=false,require_meal=false)
    state=s["configured_post_return_idle"];plan=s["daily_plan"]["active"]
    paused=plan!==nothing && plan["closed"] && now<plan["deadline_us"] &&
        mod(now,day_us)<night_us && !pending && !observing && !isempty(s["daily_plan"]["records"]) &&
        last(s["daily_plan"]["records"])["returned"] && get(last(s["daily_plan"]["records"]),"food_success",false)
    if require_meal
        meal=get(state,"meal_us",-day_us)
        paused=fld(meal,day_us)==fld(now,day_us) && mod(now,day_us)<night_us && !pending && !observing
    end
    if paused!=state["active"]
        state["active"]=paused;state["entries"]+=Int(paused)
        push!(state["records"],D("us"=>now,"active"=>paused,"reason"=>paused ? (require_meal ? "ate_after_return" : "completed_provision_goal") : "resume"))
        length(state["records"])>64 && popfirst!(state["records"])
    end
    paused
end
function configured_return_meal_due(s,now,day_us)
    state=s["configured_post_return_idle"]
    fld(get(state,"meal_us",-day_us),day_us)==fld(now,day_us) && return false
    q=get(s,"training_quest",nothing)
    if q!==nothing && q["stage"]=="completed" && fld(q["completed_us"],day_us)==fld(now,day_us)
        return true
    end
    local_returns=get(s["daily_plan"],"local_returns",Any[])
    !isempty(local_returns) && last(local_returns)["returned"] && fld(last(local_returns)["us"],day_us)==fld(now,day_us) && return true
    plan=s["daily_plan"]["active"];records=s["daily_plan"]["records"]
    plan!==nothing && plan["closed"] && now<plan["deadline_us"] && !isempty(records) && last(records)["returned"]
end
configured_return_meal_hold(s,now,day_us)=fld(get(s["configured_post_return_idle"],"meal_us",-day_us),day_us)==fld(now,day_us)
function configured_return_meal_plan(s,foods,a,now,day_us,at_home,ingestible,stock;processing_enabled=true,workable=true)
    at_home && configured_return_meal_due(s,now,day_us) || return nothing
    action=configured_food_preparation(foods,a,true,ingestible,at_home,stock;processing_enabled,processing_feasible=workable)
    action===nothing && return nothing
    D("action"=>action,"method"=>"configured_return_meal","configured_rule"=>"meal_before_cognition_pause")
end
function configured_return_meal_record!(s,action,status,at_home,now,day_us)
    action=="eat" && status=="ate" && at_home && configured_return_meal_due(s,now,day_us) || return
    s["configured_post_return_idle"]["meal_us"]=now
end
function configured_post_return_idle_tick!(s,w,a,counts,events,previous,phase,now)
    w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
    counts[a]["rest"]=get(counts[a],"rest",0)+1
    s["configured_post_return_idle"]["ticks"]+=1
    sig=(phase,"configured_post_return_idle")
    if get(previous,a,nothing)!=sig
        push!(events,D("us"=>now,"actor"=>a,"phase"=>phase,"purpose_family"=>"home","action"=>"rest",
            "status"=>"performed","method"=>"configured_post_return_idle","selection_mode"=>"configured",
            "target"=>nothing,"direction"=>nothing,"route"=>nothing,"landmark_color"=>nothing))
        previous[a]=sig
    end
end
