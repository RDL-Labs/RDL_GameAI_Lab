isempty(ARGS) && error("Specify an experiment: herbivore-cpu, predator-cpu, motion-vision-cpu, directional-vision-cpu, overgrazing-cpu")
experiment=popfirst!(ARGS)
entries=Dict("herbivore-cpu"=>"run.jl", "predator-cpu"=>"run.jl",
    "motion-vision-cpu"=>"experiment.jl", "directional-vision-cpu"=>"experiment.jl",
    "overgrazing-cpu"=>"run.jl")
haskey(entries,experiment) || error("Unknown experiment: $experiment")
include(joinpath(@__DIR__,experiment,entries[experiment]))
