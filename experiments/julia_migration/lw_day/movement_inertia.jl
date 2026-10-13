# Continuation of accepted movement, adapted from continuous_selection inertia.
inertia_state(actor)=D("actor"=>actor,"H"=>0,"threshold"=>4,"view"=>nothing,"last_us"=>-1,
    "receipt"=>nothing,"continued"=>0,"interrupts"=>D(),"records"=>Any[])
function inertia_view(move,landmarks,hazard)
    Any[move["food_coverage"],[(r["clear"],r["status"]) for r in move["energy"]["rows"]],
      sort([(f["color"],Tuple(f["azimuth"]),f["range_band"]) for f in landmarks["features"]]),
      sort([(f["appearance"],round(f["distance"];digits=1)) for f in move["visible"]]),
      hazard["coverage"],hazard["features"]]
end
function observe_inertia!(s,actor,now,view)
    check(s["actor"]==actor && now>s["last_us"],"inertia_binding")
    s["H"]=s["view"]!==nothing && s["view"]==view ? min(32,s["H"]+1) : 0
    s["view"]=view;s["last_us"]=now
end
function inertia_candidate!(s,move,hazard,phase,family,methods,source)
    r=s["receipt"]
    reason=r===nothing || r.actor!=s["actor"] || r.executed_us!=s["last_us"] ? "body_unlinked" :
        !(phase in ("exploration","return")) ? "protected_phase" :
        r.phase!=phase || r.family!=family ? "phase_changed" :
        hazard["coverage"]!="complete" || !isempty(hazard["features"]) ? "hazard_or_unknown" :
        !isempty(move["visible"]) ? "food_observed" :
        move["energy"]["rows"][3]["cost"]===nothing ? "surface_or_body_unavailable" :
        s["H"]>=s["threshold"] ? "repetition_threshold" :
        r.action!="walk" || r.status!="performed" || !r.moved || r.method===nothing ? "no_confirmed_move" :
        !haskey(methods,r.method) ? "method_unavailable" : nothing
    if reason!==nothing
        s["interrupts"][reason]=get(s["interrupts"],reason,0)+1
        return nothing
    end
    s["continued"]+=1
    push!(s["records"],D("source"=>source,"previous"=>r.source,"method"=>r.method,"H"=>s["H"]))
    length(s["records"])>32 && popfirst!(s["records"])
    D("method"=>r.method,"action"=>"walk","direction"=>2,"priority"=>10.,"question"=>"movement_progress","route"=>r.route,"inertial"=>true)
end
