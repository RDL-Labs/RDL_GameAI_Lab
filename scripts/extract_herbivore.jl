# Guarded source extraction; behavior and update order remain unchanged.
root = normpath(joinpath(@__DIR__, ".."))
old = joinpath(root, "experiments/numeric_ecology/herbivore-cpu")
dest = joinpath(root, "src/ecology/herbivore")
source = replace(read(joinpath(old, "Herbivores.jl"), String), "\r\n"=>"\n")
startswith(source, "module Herbivores") || error("Already extracted")
function section(start, stop)
    a = findfirst(start, source); b = findfirst(stop, source)
    a === nothing || b === nothing ? error("Missing section") : source[first(a):prevind(source, first(b))]
end
mkpath(dest)
write(joinpath(dest, "ids.jl"), section("const SEARCH", "mutable struct World"))
write(joinpath(dest, "types.jl"), section("mutable struct World", "function material"))
write(joinpath(dest, "world.jl"), section("function material", "function choose_state"))
write(joinpath(dest, "decision.jl"), section("function choose_state", "function step!"))
write(joinpath(dest, "update.jl"), section("function step!", "function simulate"))
tail = source[first(findfirst("function simulate", source)):end]
write(joinpath(dest, "simulation.jl"), replace(tail, r"end\s*$"=>""))
geometry = joinpath(root, "src/geometry")
mkpath(geometry)
original_geometry = joinpath(root, "experiments/julia_migration/julia/src/RDLMigrationProbe.jl")
normalize(s) = replace(s, "\r\n"=>"\n")
normalize(read(original_geometry, String)) == normalize(read(joinpath(old,"Geometry.jl"), String)) || error("Geometry differs")
write(joinpath(geometry, "RDLMigrationProbe.jl"), read(original_geometry, String))
write(original_geometry, "# Compatibility entry for the common geometry module.\ninclude(joinpath(@__DIR__, \"../../../../src/geometry/RDLMigrationProbe.jl\"))\n")
write(joinpath(old, "Herbivores.jl"), "# Compatibility entry; experiment configuration stays here.\ninclude(joinpath(@__DIR__, \"../../../src/ecology/herbivore/Herbivores.jl\"))\n")
write(joinpath(dest, "Herbivores.jl"), """
module Herbivores
using JSON3, Random
include("../../geometry/RDLMigrationProbe.jl")
using .RDLMigrationProbe
include("ids.jl")
include("types.jl")
include("world.jl")
include("decision.jl")
include("update.jl")
include("simulation.jl")
end
""")
