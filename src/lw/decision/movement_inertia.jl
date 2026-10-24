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
function record_continuation!(s,plan,loop,source)
    s["continued"]+=Int(get(plan,"inertial",false))
    push!(s["records"],D("source"=>source,"method"=>plan["method"],"H"=>loop.H,
        "probability"=>get(plan,"selection_probability",nothing),
        "candidate_count"=>get(plan,"candidate_count",0),"continued"=>get(plan,"inertial",false)))
    length(s["records"])>32 && popfirst!(s["records"])
    nothing
end
