# Experiment-only derived workspace. Cleared between checkpoint replays; never saved.
# mb_scene/node features are immutable derived data in the current implementation.
# A future in-place feature editor must invalidate this workspace explicitly.
const FIT_TRIAL_ENABLED=Ref(false)
const FIT_TRIAL_WORKSPACES=IdDict{Any,Any}()
function fit_trial_workspace(s,frame,now)
    metric=s["recognition"]["metric"]
    weights=metric["enabled"] ? (Float64(metric["weights"][1]),Float64(metric["weights"][2])) : (2.,1.)
    old=get(FIT_TRIAL_WORKSPACES,s,nothing)
    if old===nothing || old.now!=now || old.frame!==frame || old.weights!=weights
        old=(now=now,frame=frame,weights=weights,entries=Dict{String,Any}())
        FIT_TRIAL_WORKSPACES[s]=old
    end
    old
end
function fit_trial_similarity(workspace,key,frame,node,metric)
    prior=get(workspace.entries,key,nothing)
    features=get(node,"features",nothing)
    if prior!==nothing && prior.node===node && prior.signature==node["signature"] && prior.features===features
        return prior.fit
    end
    raw=mb_similarity(frame,node;metric)
    # Only immutable fields used by correspondence construction; never share parts arrays.
    fit=raw===nothing ? nothing : (confidence=raw.confidence,anchor=raw.anchor)
    workspace.entries[key]=(node=node,signature=node["signature"],features=get(node,"features",nothing),fit=fit)
    fit
end
function fit_trial_install!(root)
    path=joinpath(root,"source/src/lw/learning/mb_recognition.jl")
    source=replace(read(path,String),r"(?m)^include.*\r?\n"=>"")
    before="    # Cheap retrieval order, not a declaration of identity."
    count(before,source)==1 || error("workspace anchor")
    source=replace(source,before=>"    fit_workspace=FIT_TRIAL_ENABLED[] ? fit_trial_workspace(s,frame,now) : nothing\n"*before)
    before="fit=mb_similarity(frame,node;metric=s[\"recognition\"][\"metric\"]);fit===nothing && continue"
    count(before,source)==1 || error("fit anchor")
    source=replace(source,before=>"fit=fit_workspace===nothing ? mb_similarity(frame,node;metric=s[\"recognition\"][\"metric\"]) : fit_trial_similarity(fit_workspace,key,frame,node,s[\"recognition\"][\"metric\"]);fit===nothing && continue")
    Base.include_string(Main,source,path)
end
