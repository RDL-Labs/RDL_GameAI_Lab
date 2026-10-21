function select_target(targets,model,pressure)
    candidates=Any[]
    for target in sort(unique(targets))
        state=get(pressure.methods,target,nothing)
        H=state===nothing ? 0 : state.H
        theta=state===nothing ? pressure.parent.threshold : state.threshold
        penalty=H>=theta ? min(2,H/theta) : 0
        push!(candidates,D("target"=>target,"H"=>H,"threshold"=>theta,
            "score"=>get(get(model,target,D()),"expectation",.5)-penalty))
    end
    if pressure.parent.H>=pressure.parent.threshold
        push!(candidates,D("target"=>nothing,"score"=>.25,"reason"=>"reconsider_existing_activity"))
    end
    chosen=isempty(candidates) ? nothing : candidates[argmin([(-c["score"],c["target"]===nothing ? "" : c["target"]) for c in candidates])]
    (chosen===nothing ? nothing : chosen["target"],D("candidates"=>candidates,"selected"=>deepcopy(chosen)))
end
