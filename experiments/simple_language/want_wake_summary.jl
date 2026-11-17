using JSON3,Serialization,Test
original,fixed=abspath.(ARGS)
include(joinpath(original,"continue20/source/integrations/lightweight_julia/native.jl"))
old=deserialize(joinpath(original,"continue20/checkpoints/day-022.jls")).state
new=deserialize(joinpath(fixed,"checkpoints/day-022.jls")).state
cutoff=362943000000
prior=filter(e->e["us"]<cutoff,old[:events]);replayed=filter(e->e["us"]<cutoff,new[:events])
@test prior==replayed
offer="npc_b:362942000000:op:362942000000:npc_b"
outcomes=[r for r in new[:items]["records"] if get(r,"root_id",get(r,"id",""))==offer]
@test any(r->r["status"] in ("declined","exchanged") && r["us"]<362972000000,outcomes)
@test !any(r->r["status"]=="expired",outcomes)
notices=get(new[:mb_maps]["npc_d"]["task_focus"]["wakeups"],"trade_offer",0)
@test notices>0
trace=get(new[:relations]["npc_b"],"gradient_maps",Dict("records"=>Any[]))["records"]
@test any(r->r["source"]=="items:offer:npc_b:362942000000",trace)
report=(pre_activation_events_match=true,outcomes=outcomes,trade_wakeups=notices,request_trace_retained=true)
write(joinpath(fixed,"fix_summary.json"),JSON3.write(report))
println(JSON3.write(report))
