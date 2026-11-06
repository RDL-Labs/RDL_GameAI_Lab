# Explicit initial sleep schedule: first performed night rest enters sleep;
# morning releases the external-input gate. Memory consolidation is independent.
function configured_sleep_gate_active(learning,now,day_us)
    gate=get(learning["sleep"],"external_gate",nothing)
    gate!==nothing && gate["active"] && gate["day"]==div(now,day_us)
end
function configured_sleep_gate_enter!(learning,now,day_us;at_home=false)
    sleep=learning["sleep"]
    gate=get!(()->D("active"=>false,"day"=>div(now,day_us),"entered_us"=>nothing,"blocked_ticks"=>0),sleep,"external_gate")
    if !gate["active"]
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
