# Stable entry point; reuse the single existing native LW implementation.
include(joinpath(@__DIR__,"native.jl"))
if abspath(PROGRAM_FILE)==@__FILE__
    native_main(ARGS)
end
