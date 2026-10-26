module Herbivores
using JSON3, Random
include("../../geometry/RDLMigrationProbe.jl")
using .RDLMigrationProbe
include("ids.jl")
include("features.jl")
include("types.jl")
include("world.jl")
include("perception.jl")
include("decision.jl")
include("update.jl")
include("simulation.jl")
end
