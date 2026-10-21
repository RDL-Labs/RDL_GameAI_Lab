module RDLGameAI
include("lw/LW.jl")
include("ecology/herbivore/Herbivores.jl")
include("ecology/predator-cpu/Predators.jl")
include("ecology/motion-vision-cpu/MotionVision.jl")
include("ecology/directional-vision-cpu/DirectionalVision.jl")
include("ecology/overgrazing-cpu/Overgrazing.jl")
include("learning/MemoryBlocks.jl")
export LW, Herbivores, MemoryBlocks
export Predators, MotionVision, DirectionalVision, Overgrazing
end
