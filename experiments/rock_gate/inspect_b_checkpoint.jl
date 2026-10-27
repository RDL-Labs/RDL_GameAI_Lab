using JSON3, Serialization
root=abspath(ARGS[1]);include(joinpath(root,"source/integrations/lightweight_julia/native.jl"))
out=Any[]
for day in (53,84)
 c=deserialize(joinpath(root,"ordinary/checkpoints/day-"*lpad(day,3,'0')*".jls"))
 @assert c.code==checkpoint_code_hash()
 m=c.state[:mb_maps]["npc_b"]
 push!(out,D("day"=>day,"active"=>m["parent_mb"]["active"],
 "parent_records"=>m["parent_mb"]["records"][max(1,end-2):end],
 "arrival"=>D(g=>D("mode"=>s["mode"]) for (g,s) in m["goal_arrival"])))
 c=nothing;GC.gc()
end
write(ARGS[2],JSON3.write(out))
