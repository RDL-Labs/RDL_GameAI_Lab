include(joinpath(@__DIR__,"../../body/load.jl"))
# Human death is a physical limit, independent of the legacy collapse switch.
configured_collapse_active(body;enabled=true)=enabled && body.reserve<=0 # legacy fixtures only
configured_collapse_active(body::HumanBody;enabled=true)=!body_alive(body)
function configured_collapse_tick!(map,w,a,counts,events,previous,now)
    terminal=w.bodies[a] isa HumanBody
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
          "action"=>"rest","status"=>gate_status,"method"=>gate_name,"selection_mode"=>terminal ? "physical" : "configured",
          "configured_rule"=>terminal ? nothing : gate_name,"target"=>nothing,"direction"=>nothing,"route"=>nothing,"landmark_color"=>nothing))
        previous[a]=sig
    end
end
