# GameAI-local reusable selection loop. Candidate generation/evaluation are adapters.
mutable struct MethodNode
    H::Int
    threshold::Int
    last_selected::Int
end
mutable struct BasicLoop
    goal::String
    parent::Union{Nothing,String}
    H::Int
    threshold::Int
    methods::Dict{String,MethodNode}
    sequence::Int
    trial::Any
    receipt::Any
    events::Vector{Any}
end
BasicLoop(goal;parent=nothing,threshold=2)=begin
    check(threshold>0 && parent!=goal,"loop_identity")
    BasicLoop(goal,parent,0,threshold,Dict{String,MethodNode}(),0,nothing,nothing,Any[])
end

function choose_method!(s::BasicLoop,candidates,source)
    check(s.trial===nothing,"loop_active_trial")
    isempty(candidates) && return nothing # Unknown/blocked is not made feasible here.
    names=[c["method"] for c in candidates]
    check(length(names)==length(unique(names)),"loop_duplicate_candidate")
    check(all(isfinite(c["priority"]) for c in candidates),"loop_score")
    for name in names
        get!(s.methods,name,MethodNode(0,s.threshold,0))
    end
    # Once all current methods are unresolved, bounded penalties alone would
    # restore the original priority forever. Reconsider the least recent method.
    reconsider=all(s.methods[name].H>=s.methods[name].threshold for name in names)
    selected=first(sort(candidates,by=c->begin
        n=s.methods[c["method"]]
        reconsider ? (Float64(n.last_selected),-c["priority"],c["method"]) :
            (-c["priority"]+min(2.,n.H/n.threshold),Float64(n.last_selected),c["method"])
    end))
    s.sequence+=1;s.methods[selected["method"]].last_selected=s.sequence
    s.trial=(source=source,method=selected["method"],question=selected["question"])
    merge(copy(selected),D("selection_mode"=>reconsider ? "reconsider_unresolved" : "weighted"))
end

function resolve_method!(s::BasicLoop,source,method_value,goal_value;accepted=true)
    check(accepted,"loop_unaccepted_result")
    check(all(v===nothing || v isa Bool for v in (method_value,goal_value)),"loop_evidence")
    evidence=(source=source,method_value=method_value,goal_value=goal_value)
    if s.receipt!==nothing && s.receipt.source==source
        check(s.receipt==evidence,"loop_result_conflict");return false
    end
    check(s.trial!==nothing && s.trial.source==source,"loop_result_binding")
    n=s.methods[s.trial.method];before=n.H;parent_before=s.H
    method_value!==nothing && (n.H=method_value ? 0 : min(32,n.H+1))
    goal_value!==nothing && (s.H=goal_value ? 0 : min(32,s.H+1))
    push!(s.events,(source=source,method=s.trial.method,question=s.trial.question,
        E=method_value===nothing ? nothing : Int(!method_value),H_before=before,H_after=n.H,
        goal_E=goal_value===nothing ? nothing : Int(!goal_value),goal_H_before=parent_before,goal_H_after=s.H))
    length(s.events)>32 && popfirst!(s.events)
    s.receipt=evidence;s.trial=nothing;true
end
loop_snapshot(s::BasicLoop)=D("goal"=>s.goal,"parent"=>s.parent,"H"=>s.H,"threshold"=>s.threshold,
    "sequence"=>s.sequence,"methods"=>D(k=>D("H"=>v.H,"threshold"=>v.threshold,"last_selected"=>v.last_selected) for (k,v) in s.methods),
    "events"=>copy(s.events))

function search_candidates(move,target,loop)
    candidates=Any[D("method"=>"survey","action"=>"scan","priority"=>2.,"question"=>"target_observed")]
    # Parent unresolved pressure expands current feasible alternatives; no action quota.
    if target!==nothing || loop.H>=loop.threshold
        for row in move["energy"]["rows"]
            row["cost"]===nothing && continue
            index=parse(Int,row["ref"]);angle=deg2rad(Float64(ANGLES[index+1]))
            alignment=target===nothing ? 0. : cos(atan(target["right"],target["forward"])-angle)
            push!(candidates,D("method"=>"step_$(ANGLES[index+1])","action"=>"walk","direction"=>index,
                "priority"=>target===nothing ? 1.5 : 3.0 + alignment,
                "question"=>target===nothing ? "target_observed" : "target_nearer"))
        end
    end
    candidates
end
