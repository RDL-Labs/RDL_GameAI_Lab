module Herbivores
using JSON3, Random
include("../../geometry/RDLMigrationProbe.jl")
using .RDLMigrationProbe
include("ids.jl")
include("features.jl")
include("types.jl")
include("world.jl")
# Legacy single-layer world shares perception, but has no neighbor cache.
include("../../lw/configured_paths/rabbit_grass_layers.jl")
rabbit_neighbor_clear(w::World,a,i,j,t,p,q)=clear(w,p,q)
include("perception.jl")
include("decision.jl")
include("update.jl")
include("simulation.jl")
end
