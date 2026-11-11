# 暫定固定: scene.sleep_external_gate (default true) stops external input after
# performed night rest at an observed home, until morning, to reduce cognition cost.
# Uses the caller's home observation, not hidden world coordinates. Outside rest
# remains ordinary cognition. Replace with safety/anxiety-based sleep selection later.
# Memory consolidation is independent of this configured input gate.
function configured_sleep_gate_active(learning,now,day_us)
    gate=get(learning["sleep"],"external_gate",nothing)
    gate!==nothing && gate["active"] && get(gate,"at_home",false) && gate["day"]==div(now,day_us)
end
function configured_sleep_gate_enter!(learning,now,day_us;at_home=false)
    at_home || return nothing
    sleep=learning["sleep"]
    gate=get!(()->D("active"=>false,"day"=>div(now,day_us),"entered_us"=>nothing,"blocked_ticks"=>0),sleep,"external_gate")
    if !configured_sleep_gate_active(learning,now,day_us)
        gate["day"]=div(now,day_us)
        gate["active"]=true;gate["entered_us"]=now+1_000_000;gate["at_home"]=at_home
    end
    gate
end
function configured_sleep_gate_tick!(learning,w,a,counts,events,previous,now)
    w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
    counts[a]["rest"]=get(counts[a],"rest",0)+1
    learning["sleep"]["external_gate"]["blocked_ticks"]+=1
    sig=("night","sleep_external_gate")
    if get(previous,a,nothing)!=sig
        push!(events,D("us"=>now,"actor"=>a,"phase"=>"night","purpose_family"=>nothing,
            "action"=>"rest","status"=>"performed","method"=>"sleep_external_gate",
            "selection_mode"=>"configured","configured_rule"=>"sleep_external_gate",
            "target"=>nothing,"direction"=>nothing,"route"=>nothing,"landmark_color"=>nothing))
        previous[a]=sig
    end
end
