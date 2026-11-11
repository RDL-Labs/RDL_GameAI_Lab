# Diagnostic instrumentation only. Nested timings must not be summed.
const candidate_stats=Dict{String,Float64}()
const candidate_fixtures=Any[]
const candidate_audit_active=Ref(false)
candidate_add!(k,v=1)=(candidate_stats[k]=get(candidate_stats,k,0.)+v)
function candidate_timed(f,label,args...;kwargs...)
    m=@timed f(args...;kwargs...)
    candidate_add!(label*"_calls");candidate_add!(label*"_seconds",m.time)
    candidate_add!(label*"_bytes",m.bytes)
    m.value
end
function candidate_batch(s,candidates,goal,target)
    candidate_add!("batches")
    count_plain=count(p->!haskey(p,"mb_path"),candidates)
    candidate_add!("candidates",length(candidates));candidate_add!("plain_candidates",count_plain)
    candidate_add!("reusable_plain",max(0,count_plain-1))
    if length(candidate_fixtures)<32 && mod(Int(candidate_stats["batches"]),100)==1
        slim=Dict{String,Any}(k=>deepcopy(s[k]) for k in ("parent_mb","goal_arrival","daily_plan") if haskey(s,k))
        push!(candidate_fixtures,(s=slim,candidates=deepcopy(candidates),goal=goal,target=deepcopy(target)))
    end
    candidate_audit_active[]=true
    try
        candidate_timed(LW.mb_parent_candidates_raw!,"batch",s,candidates,goal,target)
    finally
        candidate_audit_active[]=false
    end
end
parent_source=read(joinpath(replay_root,"source/src/lw/learning/mb_parent.jl"),String)
parent_source=replace(parent_source,r"(?m)^include.*\r?\n"=>"")
parent_source=replace(parent_source,"function mb_parent_estimate!("=>"function mb_parent_estimate_raw!(",
    "function mb_parent_candidates!("=>"function mb_parent_candidates_raw!(",
    "    D(Pair{String,Any}["=>"    Main.candidate_timed(D,\"estimate_dictionary\",Pair{String,Any}[")
Base.include_string(LW,parent_source)
budget_source=read(joinpath(replay_root,"source/src/lw/learning/mb_plan_budget.jl"),String)
budget_source=replace(budget_source,"function mb_plan_budget("=>"function mb_plan_budget_raw(")
Base.include_string(LW,budget_source)
Base.include_string(LW,"""
mb_parent_estimate!(s,p,goal,target;kwargs...)=Main.candidate_audit_active[] ? Main.candidate_timed(mb_parent_estimate_raw!,"estimate",s,p,goal,target;kwargs...) : mb_parent_estimate_raw!(s,p,goal,target;kwargs...)
mb_plan_budget(s,e,goal)=Main.candidate_audit_active[] ? Main.candidate_timed(mb_plan_budget_raw,"budget",s,e,goal) : mb_plan_budget_raw(s,e,goal)
mb_parent_candidates!(s,candidates,goal,target)=Main.candidate_batch(s,candidates,goal,target)
""")
