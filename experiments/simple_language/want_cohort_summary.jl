using JSON3,Serialization
root=abspath(ARGS[1])
include(joinpath(root,"continue20/source/integrations/lightweight_julia/native.jl"))
records=JSON3.read(read(joinpath(root,"continue20/want_voice_result.json"),String))[:records]
outcomes=Any[]
for p in records
 p.event=="proposal" || continue
 day=div(Int(p.us),17_280_000_000)+1
 saved=deserialize(joinpath(root,"continue20/checkpoints/day-"*lpad(day,3,'0')*".jls"))
 needle="$(p.actor):$(p.us):op:$(p.us):$(p.actor)"
 matched=[r for r in saved.state[:items]["records"] if get(r,"root_id",get(r,"id",""))==needle]
 push!(outcomes,(actor=p.actor,target=p.target,day=day,records=matched))
end
write(joinpath(root,"request_outcomes.json"),JSON3.write(outcomes))
println(JSON3.write(outcomes))
