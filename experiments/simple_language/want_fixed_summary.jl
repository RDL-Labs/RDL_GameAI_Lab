using JSON3,Serialization
root=abspath(ARGS[1])
include(joinpath(root,"continue20/source/integrations/lightweight_julia/native.jl"))
summary=Any[]
for (stage,start) in (("continue20",13),("mixed20",33))
 rows=JSON3.read(read(joinpath(root,stage,"want_voice_result.json"),String)).records
 proposals=filter(r->r.event=="proposal" && r.us>=start*17_280_000_000,rows)
 outcomes=Any[]
 for p in proposals
  day=div(Int(p.us),17_280_000_000)+1
  s=deserialize(joinpath(root,stage,"checkpoints/day-"*lpad(day,3,'0')*".jls")).state
  id="$(p.actor):$(p.us):op:$(p.us):$(p.actor)"
  matches=[r for r in s[:items]["records"] if get(r,"root_id",get(r,"id",""))==id]
  push!(outcomes,(day=day,actor=p.actor,target=p.target,status=isempty(matches) ? "not_found" : last(matches)["status"],states=[r["status"] for r in matches]))
 end
 push!(summary,(stage=stage,outcomes=outcomes))
end
r=JSON3.read(read(joinpath(root,"mixed20/run/result.json"),String))
report=(requests=summary,bodies=Dict(string(a)=>v.body for (a,v) in pairs(r.final_agents)))
write(joinpath(root,"request_summary.json"),JSON3.write(report))
println(JSON3.write(report))
