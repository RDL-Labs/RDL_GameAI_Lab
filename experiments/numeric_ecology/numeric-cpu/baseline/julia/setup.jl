using Pkg
VERSION == v"1.13.1" || error("expected Julia 1.13.1")
if isfile(joinpath(@__DIR__, "Manifest.toml"))
    Pkg.instantiate()
else
    Pkg.add(["JSON3", "BenchmarkTools"])
end
Pkg.precompile()
Pkg.status()
