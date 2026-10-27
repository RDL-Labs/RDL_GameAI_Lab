# GameAI-local reusable selection loop. Candidate generation/evaluation are adapters.
using Random
goal_result_H(H,success;increment=1.)=success ? 0. : min(32.,H+increment)
mutable struct MethodNode
    H::Float64
    threshold::Float64
    last_selected::Int
    reward::Float64
    failure_count::Int
    failure_H_total::Float64
end
MethodNode(H,threshold,last_selected)=MethodNode(H,threshold,last_selected,0.,0,0)
mutable struct BasicLoop
    goal::String
    parent::Union{Nothing,String}
    H::Float64
    threshold::Float64
    methods::Dict{String,MethodNode}
    sequence::Int
    trial::Any
    receipt::Any
    events::Vector{Any}
    probabilistic::Bool
    rng::Xoshiro
    seed::UInt64
    last_method::Union{Nothing,String}
    credit_path::Vector{String}
end
BasicLoop(goal;parent=nothing,threshold=2,probabilistic=false,seed=0)=begin
    check(threshold>0 && parent!=goal,"loop_identity")
    # Stable actor/purpose stream; never Julia's process-randomized hash.
    stream=UInt64(seed)
    for b in codeunits(goal);stream=(stream ⊻ UInt64(b))*UInt64(0x100000001b3);end
    BasicLoop(goal,parent,0,threshold,Dict{String,MethodNode}(),0,nothing,nothing,Any[],probabilistic,Xoshiro(stream),stream,nothing,String[])
end

# Read-only comparison for diagnostics and composing fields; no snapshot needed.
"Finite parent-H admission before expensive fields; never invents feasible methods."
function parent_candidates(s::BasicLoop,candidates)
    s.probabilistic && return candidates # all feasible alternatives retain probability
    # Saturated parent H must still expose every method even with a high threshold.
    level=s.H>=32 ? 2 : min(2,fld(s.H,s.threshold))
    limit=level==0 ? 2 : level==1 ? 4 : length(candidates)
    length(candidates)<=limit && return candidates
    uses=Dict{String,Int}()
    for event in s.events # already bounded to 32 accepted results
        uses[event.method]=get(uses,event.method,0)+1
    end
    # Familiar methods first, then current proposal priority and deterministic ID.
    key(c)=(-get(uses,c["method"],0),-c["priority"],c["method"])
    admitted=Any[]
    for c in candidates
        push!(admitted,c)
        sort!(admitted;by=key)
        length(admitted)>limit && pop!(admitted)
    end
    admitted
end

function ranked_method_choice(s::BasicLoop,candidates)
    isempty(candidates) && return nothing
    node(name)=get(s.methods,name,nothing)
    # Once all current methods are unresolved, bounded penalties alone would
    # restore the original priority forever. Reconsider the least recent method.
    reconsider=all(c->begin
        n=node(c["method"]);n!==nothing && n.H>=n.threshold
    end,candidates)
    key(c)=begin
        n=node(c["method"])
        h=n===nothing ? 0 : n.H;t=n===nothing ? s.threshold : n.threshold
        last=n===nothing ? 0 : n.last_selected
        reconsider ? (Float64(last),-c["priority"],c["method"]) :
            (-c["priority"]+min(2.,h/t),Float64(last),c["method"])
    end
    selected=first(candidates);best=key(selected)
    for c in Iterators.drop(candidates,1)
        k=key(c)
        if isless(k,best);selected=c;best=k;end
    end
    selected
end

"Read-only distribution: learned/current candidate scores define probabilities; no recency bonus."
failure_repulsion(n::MethodNode)=log1p(n.failure_H_total)
function method_distribution(s::BasicLoop,candidates)
    isempty(candidates) && return Float64[]
    length(candidates)==1 && return [1.]
    temperature=1+s.H/s.threshold
    scores=map(candidates) do c
        n=get(s.methods,c["method"],MethodNode(0,s.threshold,0))
        learned=log1p(n.reward)
        local_temperature=get(c,"goal_arrival",false) ? 1. : temperature
        (c["priority"]+learned-failure_repulsion(n)-min(2.,n.H/n.threshold))/local_temperature+get(c,"observation_log_prior",0.)
    end
    weights=exp.(max.(-600.,scores.-maximum(scores)));weights./=sum(weights)
    weights
end
function method_choice(s::BasicLoop,candidates)
    isempty(candidates) && return nothing
    s.probabilistic ? candidates[argmax(method_distribution(s,candidates))] : ranked_method_choice(s,candidates)
end

function choose_method!(s::BasicLoop,candidates,source)
    check(s.trial===nothing,"loop_active_trial")
    isempty(candidates) && return nothing # Unknown/blocked is not made feasible here.
    names=[c["method"] for c in candidates]
    check(length(names)==length(unique(names)),"loop_duplicate_candidate")
    check(all(isfinite(c["priority"]) for c in candidates),"loop_score")
    check(all(isfinite(get(c,"observation_log_prior",0.)) for c in candidates),"loop_observation_score")
    for name in names
        get!(s.methods,name) do
            MethodNode(0,s.threshold,0)
        end
    end
    reconsider=all(s.methods[name].H>=s.methods[name].threshold for name in names)
    probabilities=s.probabilistic ? method_distribution(s,candidates) : nothing
    selected=if probabilities===nothing
        method_choice(s,candidates)
    else
        u=rand(s.rng);index=length(candidates);cumulative=0.
        for i in eachindex(candidates)
            cumulative+=probabilities[i]
            if u<cumulative;index=i;break;end
        end
        candidates[index]
    end
    s.sequence+=1;s.methods[selected["method"]].last_selected=s.sequence
    s.trial=(source=source,method=selected["method"],question=selected["question"])
    out=copy(selected);out["selection_mode"]=s.probabilistic ? "probabilistic_H" : reconsider ? "reconsider_unresolved" : "weighted"
    if probabilities!==nothing
        index=findfirst(c->c===selected,candidates)
        out["selection_probability"]=probabilities[index]
        out["candidate_count"]=length(candidates)
        out["failure_repulsion"]=failure_repulsion(s.methods[selected["method"]])
    end
    s.last_method=selected["method"];out
end

function resolve_method!(s::BasicLoop,source,method_value,goal_value;accepted=true,creditable=method_value===true,goal_H_increment=1,completion_reward=nothing)
    check(accepted,"loop_unaccepted_result")
    check(all(v===nothing || v isa Bool for v in (method_value,goal_value)),"loop_evidence")
    check(goal_H_increment isa Real && !(goal_H_increment isa Bool) && isfinite(goal_H_increment) && goal_H_increment>=0,"loop_goal_increment")
    check(completion_reward===nothing || (goal_value===true && completion_reward isa Real && !(completion_reward isa Bool) && isfinite(completion_reward) && completion_reward>=0),"loop_completion_reward")
    evidence=(source=source,method_value=method_value,goal_value=goal_value,creditable=creditable,goal_H_increment=goal_H_increment,completion_reward=completion_reward)
    if s.receipt!==nothing && s.receipt.source==source
        check(s.receipt==evidence,"loop_result_conflict");return false
    end
    check(s.trial!==nothing && s.trial.source==source,"loop_result_binding")
    n=s.methods[s.trial.method];before=n.H;parent_before=s.H
    method_value!==nothing && (n.H=method_value ? 0 : min(32,n.H+1))
    goal_value!==nothing && (s.H=goal_result_H(s.H,goal_value;increment=goal_H_increment))
    # Keep distinct executed methods, not repetition counts. Credit is delayed
    # until this parent purpose is actually resolved, never for movement alone.
    if creditable || goal_value===true
        filter!(m->m!=s.trial.method,s.credit_path)
        push!(s.credit_path,s.trial.method)
        length(s.credit_path)>32 && popfirst!(s.credit_path)
    end
    reward=goal_value===true ? Float64(completion_reward===nothing ? max(0,parent_before-s.H) : completion_reward) : 0.
    credit=Dict{String,Float64}()
    failed=goal_value===false && method_value===false && goal_H_increment>0
    if failed
        # Retain failure evidence separately; successful experience is not erased.
        n.failure_count+=1;n.failure_H_total+=parent_before
        filter!(m->m!=s.trial.method,s.credit_path)
    end
    if goal_value===true
        eligible=filter(m->haskey(s.methods,m),s.credit_path)
        if reward>0 && !isempty(eligible)
            for m in eligible
                credit[m]=reward/length(eligible)
                s.methods[m].reward+=credit[m]
            end
        end
        empty!(s.credit_path)
    end
    push!(s.events,(source=source,method=s.trial.method,question=s.trial.question,
        E=method_value===nothing ? nothing : Int(!method_value),H_before=before,H_after=n.H,
        goal_E=goal_value===nothing ? nothing : Int(!goal_value),goal_H_before=parent_before,goal_H_after=s.H,goal_H_increment=goal_H_increment,
        reward=reward,credit=credit,failed=failed,failure_H=failed ? parent_before : nothing))
    length(s.events)>32 && popfirst!(s.events)
    s.receipt=evidence;s.trial=nothing;true
end
loop_snapshot(s::BasicLoop)=D("goal"=>s.goal,"parent"=>s.parent,"H"=>s.H,"threshold"=>s.threshold,
    "probabilistic"=>s.probabilistic,"selection_seed"=>s.seed,"last_method"=>s.last_method,
    "credit_path"=>copy(s.credit_path),
    "sequence"=>s.sequence,"methods"=>D(k=>D("H"=>v.H,"threshold"=>v.threshold,"last_selected"=>v.last_selected,"reward"=>v.reward,
        "failure_count"=>v.failure_count,"failure_H_total"=>v.failure_H_total,"failure_repulsion"=>failure_repulsion(v)) for (k,v) in s.methods),
    "events"=>copy(s.events))

function search_candidates(move,target,loop)
    candidates=Any[D("method"=>"survey","action"=>"scan","priority"=>2.,"question"=>"target_observed")]
    # Parent unresolved pressure expands current feasible alternatives; no action quota.
    if loop.probabilistic || target!==nothing || loop.H>=loop.threshold
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

# Shared by the integrated observation-to-loop handoff and its regression checks.
function forecast_method_evidence(increment,goal,same_phase,value)
    within_estimate=increment!==nothing && iszero(increment) && !goal
    within_estimate ? nothing : (same_phase || value===true ? value : nothing)
end
