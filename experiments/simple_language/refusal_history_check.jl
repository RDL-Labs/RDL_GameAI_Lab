using JSON3,Serialization
root=ARGS[1];out=ARGS[2]
include(joinpath(root,"source/src/lw/LW.jl"))
f=deserialize(joinpath(out,"refusal-input.jls"))
c=deserialize(joinpath(root,"run/checkpoints/day-040.jls"))
records=c.state[:response_stats][f.owner]["records"]
found=filter(r->get(r,"source",nothing)==f.seed,records)
write(joinpath(out,"historical-match.json"),JSON3.write((matches=found,retained_records=length(records))))
println(JSON3.write((matches=found,retained_records=length(records))))
