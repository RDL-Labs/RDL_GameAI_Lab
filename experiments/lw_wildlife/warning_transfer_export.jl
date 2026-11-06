include(joinpath(ARGS[1],"source/experiments/lw_wildlife/animals_only.jl"))
s,p=deserialize(joinpath(ARGS[1],"day-3.jls"))
records=[NamedTuple{fieldnames(TrialPredator)}(Tuple(getfield(x,k) for k in fieldnames(TrialPredator))) for x in p]
serialize(ARGS[2],(s,records))
