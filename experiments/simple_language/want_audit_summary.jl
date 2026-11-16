using JSON3,Serialization
original,replay=abspath.(ARGS)
include(joinpath(original,"continue20/source/integrations/lightweight_julia/native.jl"))
old=deserialize(joinpath(original,"continue20/checkpoints/day-031.jls")).state
new=deserialize(joinpath(replay,"checkpoints/day-031.jls")).state
checks=Dict("events"=>isequal(old[:events],new[:events]),"counts"=>isequal(old[:counts],new[:counts]),
 "positions"=>isequal(old[:w].positions,new[:w].positions),"personal_food"=>isequal(old[:foods].personal,new[:foods].personal))
checks["trade_rng"]=all(old[:incidental_items][a]["social"][r].rng==new[:incidental_items][a]["social"][r].rng for a in IDS for r in ("offer","response"))
traces=[JSON3.read(line) for line in eachline(joinpath(replay,"direct_audit.jsonl"))]
summaries=Any[]
for t in (362942000000,380222000000,432062000000,518462000000)
 rows=filter(r->r.actor=="npc_d" && t<=r.us<=t+30_000_000,traces)
 push!(summaries,(us=t,day=div(t,17_280_000_000)+1,
 gates=[(us=r.us,plan=r.data.prior_plan,inventory=r.data.inventory) for r in rows if r.event=="trade_gate"],
 entries=[(us=r.us,incoming=r.data.incoming,stock=r.data.stock) for r in rows if r.event=="plan_entry"],
 trials=[(us=r.us,role=r.data.role,trial=r.data.trial) for r in rows if r.event=="trial_gate"],
 rejected=[r for r in rows if r.event=="gain_unavailable" || (r.event=="valuation" && r.data.gradient.total<-.01)]))
end
write(joinpath(replay,"audit_summary.json"),JSON3.write((checks=checks,scenes=summaries)))
println(JSON3.write(checks))
for s in summaries
 println(JSON3.write((day=s.day,gate_count=length(s.gates),entry_count=length(s.entries),
  first_gates=s.gates[1:min(3,end)],first_entries=s.entries[1:min(2,end)],first_trials=s.trials[1:min(2,end)],
  rejected=s.rejected[1:min(3,end)])))
end
@assert all(values(checks))
