# Explicit execution gate, not learned rest preference or death.
configured_collapse_active(body;enabled=true)=enabled && body.reserve<=0
function configured_collapse_tick!(map,w,a,counts,events,previous,now)
    state=get!(()->D("blocked_ticks"=>0,"entries"=>0,"active"=>false),map,"collapse_gate")
    if !state["active"];state["entries"]+=1;state["entered_us"]=now;end
    state["active"]=true;state["blocked_ticks"]+=1
    w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
    counts[a]["collapsed"]=get(counts[a],"collapsed",0)+1
    sig=("collapsed","collapse_gate")
    if get(previous,a,nothing)!=sig
        push!(events,D("us"=>now,"actor"=>a,"phase"=>"collapsed","purpose_family"=>nothing,
          "action"=>"rest","status"=>"collapsed","method"=>"collapse_gate","selection_mode"=>"configured",
          "configured_rule"=>"collapse_gate","target"=>nothing,"direction"=>nothing,"route"=>nothing,"landmark_color"=>nothing))
        previous[a]=sig
    end
end
