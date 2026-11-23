using Serialization,JSON3
root=ARGS[1];include(joinpath(root,"source/src/lw/LW.jl"))
c=deserialize(joinpath(root,"run/checkpoints/day-040.jls"))
for (a,s) in c.state[:response_stats]
 for r in s["records"]; get(r,"selected",nothing)=="refuse" && get(r,"give_probability",0.)>0 && println(JSON3.write((actor=a,source=r["source"],give_probability=r["give_probability"],draw=r["draw"])));end
end
