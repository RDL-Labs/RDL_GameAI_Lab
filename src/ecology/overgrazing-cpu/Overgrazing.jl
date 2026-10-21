module Overgrazing
include("Herbivores.jl")
const H=Herbivores
include("simulation.jl")
export simulate_overgrazing
end
