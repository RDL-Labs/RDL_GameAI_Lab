using JSON3
include("../../src/ecology/directional-vision-cpu/DirectionalVision.jl")
spec=JSON3.read(read(joinpath(@__DIR__,"../numeric_ecology/herbivore-cpu/map-spec.json"),String))
r=DirectionalVision.trial(spec;rich=true,days=3,motion=true,directional=true)
open(ARGS[1],"w") do io;JSON3.write(io,r);end
println("rich directional predator trial complete")
