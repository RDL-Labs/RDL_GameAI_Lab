include("../decision/policies.jl")

"Run replaceable social/feeding policies in the existing ContactWorld."
function step_policies!(w,policies,tick)
    tick>=0 && tick==w.seconds || throw(ArgumentError("policy clock"))
    all(a->haskey(policies,a),IDS) || throw(ArgumentError("missing actor policy"))
    observations=Dict(a=>observe(w,a) for a in IDS)
    plans=Dict(a=>choose(policies[a],observations[a]) for a in IDS)
    w.seconds=tick+1
    results=Dict(a=>communicate!(w,a,"policy:$tick:$a",plans[a].action,
        get(plans[a],:target,nothing),get(plans[a],:reply,nothing)) for a in IDS)
    results
end
