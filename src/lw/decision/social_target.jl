function select_target(targets,model,pressure;relation=nothing,seed=nothing,situation=nothing)
    relation!==nothing && check(pressure.parent.goal_id==relation["actor"]*":obtain-aid" && seed isa AbstractString,"target_relation_owner_seed")
    unified=hasproperty(pressure,:loop)
    unified && check(seed isa AbstractString,"target_forecast_seed")
    candidates=Any[]
    security=food_security(relation)
    self_forecast=security===nothing ? nothing : get(security,"self_reliance",nothing)
    confidence=self_forecast===nothing ? 0. : self_forecast["confidence"]
    for target in sort(unique(targets))
        peer_context=social_aid_context(relation,target,situation)
        peer_resources=aid_resource_prediction(peer_context)
        peer_resources["factor"]>0 || continue
        state=get(pressure.methods,target,nothing)
        H=state===nothing ? 0 : state.H
        theta=state===nothing ? pressure.parent.threshold : state.threshold
        # The persistent common loop applies its own method H and learned
        # outcomes. Do not apply the old threshold penalty a second time.
        penalty=!unified && H>=theta ? min(2,H/theta) : 0
        relationship=relation===nothing ? nothing : unified ?
            social_relation_bias(relation,target,"request";situation=peer_context,H=pressure.parent.H) :
            social_relation_bias(relation,target,"request")
        candidate=D("target"=>target,"H"=>H,"threshold"=>theta,
            "score"=>(relationship===nothing ? get(get(model,target,D()),"expectation",.5) : .5+relationship["weight"])-penalty+log1p(food_anxiety(food_security(relation))))
        relationship!==nothing && (candidate["relationship"]=relationship)
        candidate["score"]+=log(peer_resources["factor"])
        candidate["resource_prediction"]=peer_resources
        candidate["context"]=peer_context
        if self_forecast!==nothing
            # Aid competes with doing it oneself; rejection evidence continues
            # through the existing partner MB and common method loop.
            candidate["score"]-=FOOD_SECURITY_RULES.self_reliance_weight*confidence
            candidate["self_reliance"]=self_forecast
        end
        push!(candidates,candidate)
    end
    if unified || pressure.parent.H>=pressure.parent.threshold
        push!(candidates,D("target"=>nothing,"score"=>.25+FOOD_SECURITY_RULES.self_reliance_weight*confidence,"reason"=>"reconsider_existing_activity"))
    end
    if (unified || relation!==nothing) && !isempty(candidates)
        # Reuse the common H-temperature distribution. Existing aid pressure
        # remains the experience owner; this read-only adapter creates no trial.
        loop=unified ? pressure.loop : BasicLoop(relation["actor"]*":social-target";threshold=pressure.parent.threshold,probabilistic=true)
        !unified && (loop.H=pressure.parent.H)
        probabilities=method_distribution(loop,[D("method"=>c["target"]===nothing ? "existing_activity" : unified ? c["target"] : "peer:"*c["target"],"priority"=>c["score"]) for c in candidates])
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
