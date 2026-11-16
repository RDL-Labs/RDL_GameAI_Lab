using JSON3,Serialization
root=abspath(ARGS[1])
include(joinpath(root,"continue20/source/integrations/lightweight_julia/native.jl"))
reports=Any[]
for (day,t) in ((22,362942000000),(23,380222000000),(26,432062000000),(31,518462000000))
 s=deserialize(joinpath(root,"continue20/checkpoints/day-"*lpad(day,3,'0')*".jls")).state
 events=[e for e in s[:events] if e["actor"]=="npc_d" && t-5_000_000<=e["us"]<=t+35_000_000]
 preceding=filter(e->e["actor"]=="npc_d" && e["us"]<t,s[:events])
 gradients=[r for r in get(s[:relations]["npc_d"],"gradient_maps",D("records"=>Any[]))["records"] if t<=r["us"]<=t+35_000_000]
 push!(reports,(day=day,inventory=s[:w].inventory["npc_d"],previous= s[:previous]["npc_d"],response_trial=s[:incidental_items]["npc_d"]["social"]["response"].trial,preceding=isempty(preceding) ? nothing : last(preceding),events=events,gradients=gradients))
end
write(joinpath(root,"failure_audit.json"),JSON3.write(reports))
for r in reports
 println(JSON3.write((day=r.day,inventory=r.inventory,response_trial=r.response_trial,preceding=r.preceding,events=r.events,
 gradients=[(us=g["us"],selected=g["selected"],count=g["candidate_count"],candidates=[D(k=>v for (k,v) in c if k in ("action","partner","probability","compound_gradient","terms")) for c in g["candidates"]]) for g in r.gradients])))
end
