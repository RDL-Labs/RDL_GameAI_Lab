using Serialization
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
saved=deserialize(ARGS[2]);cohort=saved.state[:predator_cohort]
# Only predator memories and their clock; avoid deserializing legacy rabbit physiology in new code.
ispath(ARGS[3]) && error("fresh output required")
serialize(ARGS[3],(state=Dict(:predator_cohort=>(minds=cohort.minds,local_hunts=cohort.local_hunts,pursuits=cohort.pursuits),:wildlife=>(ticks=saved.state[:wildlife].ticks,)),source=abspath(ARGS[2])))
println("EXPORTED predator memory donor")
