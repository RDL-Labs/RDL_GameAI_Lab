# GameAI-local reusable selection loop. Candidate generation/evaluation are adapters.
using Random
include("forecast_difference.jl")
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
    h_mode::Symbol
    forecast_balances::Dict{Union{Nothing,String},Any}
end
BasicLoop(goal;parent=nothing,threshold=2,probabilistic=false,seed=0,h_mode=:forecast_difference)=begin
    check(threshold>0 && parent!=goal,"loop_identity")
    check(h_mode in (:forecast_difference,:legacy),"loop_h_mode")
    # Stable actor/purpose stream; never Julia's process-randomized hash.
    stream=UInt64(seed)
    for b in codeunits(goal);stream=(stream ⊻ UInt64(b))*UInt64(0x100000001b3);end
    BasicLoop(goal,parent,0,threshold,Dict{String,MethodNode}(),0,nothing,nothing,Any[],probabilistic,Xoshiro(stream),stream,nothing,String[],h_mode,Dict{Union{Nothing,String},Any}())
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
    reconsider=s.h_mode==:legacy && all(c->begin
        n=node(c["method"]);n!==nothing && n.H>=n.threshold
    end,candidates)
    key(c)=begin
        n=node(c["method"])
        h=n===nothing ? 0 : n.H;t=n===nothing ? s.threshold : n.threshold
        last=n===nothing ? 0 : n.last_selected
        s.h_mode==:forecast_difference ? (-c["priority"]+get(c,"forecast_H",h)/t,Float64(last),c["method"]) :
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
function method_score_parts(s::BasicLoop,c)
    n=get(s.methods,c["method"],MethodNode(0,s.threshold,0))
    learned=log1p(n.reward)
    modern=s.h_mode==:forecast_difference
    repulsion=modern ? 0. : failure_repulsion(n)
    penalty=modern ? get(c,"forecast_H",n.H)/n.threshold : min(2.,n.H/n.threshold)
    temperature=modern || get(c,"goal_arrival",false) ? 1. : 1+max(s.H,get(c,"decision_H",s.H))/s.threshold
    score=(c["priority"]+learned-repulsion-penalty)/temperature+get(c,"observation_log_prior",0.)
    (;learned,repulsion,penalty,temperature,score)
end
function method_distribution(s::BasicLoop,candidates)
    isempty(candidates) && return Float64[]
    length(candidates)==1 && return [1.]
    # Selection and diagnostic traces share exactly the same score components.
    scores=map(c->method_score_parts(s,c).score,candidates)
    weights=exp.(max.(-600.,scores.-maximum(scores)));weights./=sum(weights)
    weights
end
function method_choice(s::BasicLoop,candidates)
    isempty(candidates) && return nothing
    s.probabilistic ? candidates[argmax(method_distribution(s,candidates))] : ranked_method_choice(s,candidates)
end

"同じ関係の列挙数で重みを増やさず、最強の見込みをまとまりの代表にする。"
function relational_candidate_distribution(s::BasicLoop,candidates,relation_keys)
    length(candidates)==length(relation_keys) || error("candidate relation binding")
    probabilities=method_distribution(s,candidates)
    isempty(probabilities) && return probabilities
    totals=Dict{eltype(relation_keys),Float64}()
    peaks=Dict{eltype(relation_keys),Float64}()
    for (key,p) in zip(relation_keys,probabilities)
        totals[key]=get(totals,key,0.)+p
        peaks[key]=max(get(peaks,key,0.),p)
    end
    # 元の分布の共通正規化係数は最後に消える。乱数消費・候補順は変えない。
    adjusted=[p*peaks[key]/totals[key] for (key,p) in zip(relation_keys,probabilities)]
    adjusted./sum(adjusted)
end

function choose_method!(s::BasicLoop,candidates,source)
    check(s.trial===nothing,"loop_active_trial")
    isempty(candidates) && return nothing # Unknown/blocked is not made feasible here.
    names=[c["method"] for c in candidates]
    check(length(names)==length(unique(names)),"loop_duplicate_candidate")
    check(all(isfinite(c["priority"]) for c in candidates),"loop_score")
    check(all(isfinite(get(c,"observation_log_prior",0.)) for c in candidates),"loop_observation_score")
    check(all(c->!haskey(c,"decision_H") || (c["decision_H"] isa Real && isfinite(c["decision_H"]) && c["decision_H"]>=0),candidates),"loop_decision_H")
    check(all(c->!haskey(c,"forecast_H") || (c["forecast_H"] isa Real && !(c["forecast_H"] isa Bool) && isfinite(c["forecast_H"]) && c["forecast_H"]>=0),candidates),"loop_forecast_H")
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
        out["failure_repulsion"]=method_score_parts(s,selected).repulsion
    end
    s.last_method=selected["method"];out
end

function resolve_method!(s::BasicLoop,source,method_value,goal_value;accepted=true,creditable=method_value===true,goal_H_increment=1,completion_reward=nothing,method_forecast=nothing,goal_forecast=nothing)
    check(accepted,"loop_unaccepted_result")
    check(all(v===nothing || v isa Bool for v in (method_value,goal_value)),"loop_evidence")
    check(goal_H_increment isa Real && !(goal_H_increment isa Bool) && isfinite(goal_H_increment) && goal_H_increment>=0,"loop_goal_increment")
    check(completion_reward===nothing || (goal_value===true && completion_reward isa Real && !(completion_reward isa Bool) && isfinite(completion_reward) && completion_reward>=0),"loop_completion_reward")
    check(all(f->f===nothing || (f isa Tuple && length(f)==2 && all(x->x===nothing || (x isa Real && !(x isa Bool) && isfinite(x)),f)),(method_forecast,goal_forecast)),"loop_forecast_evidence")
    evidence=(source=source,method_value=method_value,goal_value=goal_value,creditable=creditable,goal_H_increment=goal_H_increment,completion_reward=completion_reward,method_forecast=method_forecast,goal_forecast=goal_forecast)
    if s.receipt!==nothing && s.receipt.source==source
        check(s.receipt==evidence,"loop_result_conflict");return false
    end
    check(s.trial!==nothing && s.trial.source==source,"loop_result_binding")
    n=s.methods[s.trial.method];before=n.H;parent_before=s.H
    if s.h_mode==:legacy
        method_value!==nothing && (n.H=method_value ? 0 : min(32,n.H+1))
        goal_value!==nothing && (s.H=goal_result_H(s.H,goal_value;increment=goal_H_increment))
    else
        # Boolean success/failure is not a forecast. Unmigrated callers leave H
        # unchanged rather than inventing a one-unit expectation or erasing H.
        method_forecast!==nothing && loop_forecast_difference!(s,s.trial.method,method_forecast...)
        goal_forecast!==nothing && loop_forecast_difference!(s,nothing,goal_forecast...)
    end
    # Keep distinct executed methods, not repetition counts. Credit is delayed
    # until this parent purpose is actually resolved, never for movement alone.
    if creditable || goal_value===true
        filter!(m->m!=s.trial.method,s.credit_path)
        push!(s.credit_path,s.trial.method)
        length(s.credit_path)>32 && popfirst!(s.credit_path)
    end
    reward=goal_value===true ? Float64(completion_reward===nothing ? max(0,parent_before-s.H) : completion_reward) : 0.
    credit=Dict{String,Float64}()
    failed=s.h_mode==:forecast_difference ? n.H>before : goal_value===false && method_value===false && goal_H_increment>0
    failure_H=s.h_mode==:forecast_difference ? max(0.,n.H-before) : parent_before
    if failed
        # Retain failure evidence separately; successful experience is not erased.
        n.failure_count+=1;n.failure_H_total+=failure_H
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
        goal_E=goal_value===nothing ? nothing : Int(!goal_value),goal_H_before=parent_before,goal_H_after=s.H,goal_H_increment=s.h_mode==:forecast_difference ? max(0.,s.H-parent_before) : goal_H_increment,
        reward=reward,credit=credit,failed=failed,failure_H=failed ? failure_H : nothing,
        method_forecast=method_forecast,goal_forecast=goal_forecast))
    length(s.events)>32 && popfirst!(s.events)
    s.receipt=evidence;s.trial=nothing;true
end
loop_snapshot(s::BasicLoop)=D("goal"=>s.goal,"parent"=>s.parent,"H"=>s.H,"threshold"=>s.threshold,
    "h_mode"=>String(s.h_mode),"forecast_balances"=>D((k===nothing ? "parent" : "method:"*k)=>deepcopy(v) for (k,v) in s.forecast_balances),
    "probabilistic"=>s.probabilistic,"selection_seed"=>s.seed,"last_method"=>s.last_method,
    "credit_path"=>copy(s.credit_path),
    "sequence"=>s.sequence,"methods"=>D(k=>D("H"=>v.H,"threshold"=>v.threshold,"last_selected"=>v.last_selected,"reward"=>v.reward,
        "failure_count"=>v.failure_count,"failure_H_total"=>v.failure_H_total,"failure_repulsion"=>s.h_mode==:forecast_difference ? 0. : failure_repulsion(v)) for (k,v) in s.methods),
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
