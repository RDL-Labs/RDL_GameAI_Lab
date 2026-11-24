include(joinpath(@__DIR__,"../../body/load.jl"))
# Human inability to act is physical, independent of the legacy collapse switch.
configured_collapse_active(body;enabled=true)=enabled && body.reserve<=0 # legacy fixtures only
configured_collapse_active(body::HumanBody;enabled=true)=!body_alive(body) || body_mobility(body)<=0
function configured_collapse_tick!(map,w,a,counts,events,previous,now)
    physical=w.bodies[a] isa HumanBody
    terminal=physical && !body_alive(w.bodies[a])
    gate_name=terminal ? "death" : "collapse_gate"
    gate_status=terminal ? "dead" : "collapsed"
    state=get!(()->D("blocked_ticks"=>0,"entries"=>0,"active"=>false),map,"collapse_gate")
    if !state["active"];state["entries"]+=1;state["entered_us"]=now;end
    state["active"]=true;state["blocked_ticks"]+=1
    w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
    counts[a][gate_status]=get(counts[a],gate_status,0)+1
    sig=(gate_status,gate_name)
    if get(previous,a,nothing)!=sig
        push!(events,D("us"=>now,"actor"=>a,"phase"=>gate_status,"purpose_family"=>nothing,
          "action"=>"rest","status"=>gate_status,"method"=>gate_name,"selection_mode"=>physical ? "physical" : "configured",
          "configured_rule"=>physical ? nothing : gate_name,"target"=>nothing,"direction"=>nothing,"route"=>nothing,"landmark_color"=>nothing))
        previous[a]=sig
    end
end
