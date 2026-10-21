# Stable router; shared Julia environment and layered implementation.
if isempty(ARGS) || ARGS[1] in ("--help", "-h")
    println("""
    RDL Game AI Lab — Julia entry
      julia run.jl lw OUTPUT [existing LW options]
      julia run.jl ecology EXPERIMENT

    Ecology experiments: herbivore-cpu, predator-cpu, motion-vision-cpu,
                         directional-vision-cpu, overgrazing-cpu
    Dependencies: follow README.md setup first (Julia 1.13.1).
    LW writes OUTPUT; ecology regenerates its experiment result files.
    """)
else
    route=popfirst!(ARGS)
    route in ("lw", "ecology") || error("Unknown route: $route. Use --help.")
    isempty(ARGS) && error("$route requires an output path or experiment name. Use --help.")
    using Pkg
    Pkg.activate(@__DIR__)
    if route=="lw"
        include(joinpath(@__DIR__,"integrations/lightweight_julia/run.jl"))
        native_main(ARGS)
    else
        include(joinpath(@__DIR__,"experiments/numeric_ecology/run.jl"))
    end
end
