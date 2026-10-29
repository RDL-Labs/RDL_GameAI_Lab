function select_target(targets,model,pressure;relation=nothing,seed=nothing)
    relation!==nothing && check(pressure.parent.goal_id==relation["actor"]*":obtain-aid" && seed isa AbstractString,"target_relation_owner_seed")
    candidates=Any[]
    for target in sort(unique(targets))
        state=get(pressure.methods,target,nothing)
        H=state===nothing ? 0 : state.H
        theta=state===nothing ? pressure.parent.threshold : state.threshold
        penalty=H>=theta ? min(2,H/theta) : 0
        relationship=relation===nothing ? nothing : social_relation_bias(relation,target,"request")
        candidate=D("target"=>target,"H"=>H,"threshold"=>theta,
            "score"=>(relationship===nothing ? get(get(model,target,D()),"expectation",.5) : .5+relationship["weight"])-penalty)
        relationship!==nothing && (candidate["relationship"]=relationship)
        push!(candidates,candidate)
    end
    if pressure.parent.H>=pressure.parent.threshold
        push!(candidates,D("target"=>nothing,"score"=>.25,"reason"=>"reconsider_existing_activity"))
    end
    if relation!==nothing && !isempty(candidates)
        # Reuse the common H-temperature distribution. Existing aid pressure
        # remains the experience owner; this read-only adapter creates no trial.
        loop=BasicLoop(relation["actor"]*":social-target";threshold=pressure.parent.threshold,probabilistic=true)
        loop.H=pressure.parent.H
        probabilities=method_distribution(loop,[D("method"=>c["target"]===nothing ? "existing_activity" : "peer:"*c["target"],"priority"=>c["score"]) for c in candidates])
        bits=foldl((x,b)->(x<<8)|UInt64(b),sha256(seed)[1:8];init=UInt64(0))
        draw=Float64(bits)/18446744073709551616.0
        index=something(findfirst(>=(draw),cumsum(probabilities)),length(candidates))
        chosen=candidates[index]
        return chosen["target"],D("candidates"=>candidates,"probabilities"=>probabilities,"draw"=>draw,
            "selected"=>deepcopy(chosen),"selection"=>"common_H_distribution")
    end
    chosen=isempty(candidates) ? nothing : candidates[argmin([(-c["score"],c["target"]===nothing ? "" : c["target"]) for c in candidates])]
    (chosen===nothing ? nothing : chosen["target"],D("candidates"=>candidates,"selected"=>deepcopy(chosen)))
end
