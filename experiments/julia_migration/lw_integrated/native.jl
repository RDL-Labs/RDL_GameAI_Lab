# Compatibility entry; canonical implementation is in src or integrations.
include(joinpath(@__DIR__, "../../../integrations/lightweight_julia/native.jl"))
if abspath(PROGRAM_FILE)==@__FILE__
    native_main(ARGS)
end
