# Declared experimental behavior: stop cognition after a completed return until night.
# Not learned attention, an embedded MB, or a biological sleep model.
configured_post_return_idle_state()=D("active"=>false,"ticks"=>0,"entries"=>0,"records"=>Any[])
function configured_post_return_idle!(s,now,day_us,night_us;pending=false,observing=false)
    state=s["configured_post_return_idle"];plan=s["daily_plan"]["active"]
    paused=plan!==nothing && plan["closed"] && now<plan["deadline_us"] &&
        mod(now,day_us)<night_us && !pending && !observing && !isempty(s["daily_plan"]["records"]) &&
        last(s["daily_plan"]["records"])["returned"]
    if paused!=state["active"]
        state["active"]=paused;state["entries"]+=Int(paused)
        push!(state["records"],D("us"=>now,"active"=>paused,"reason"=>paused ? "completed_return" : "resume"))
        length(state["records"])>64 && popfirst!(state["records"])
    end
    paused
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
