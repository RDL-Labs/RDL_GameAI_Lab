# Compatibility entry; canonical implementation is in src or integrations.
include(joinpath(@__DIR__, "../../../src/lw/simulation/integrated.jl"))
if abspath(PROGRAM_FILE)==@__FILE__
    r,summary=run_integrated(JSON3.read(read(ARGS[1],String)))
    open(ARGS[2],"w") do io;JSON3.write(io,r);end
    open(ARGS[3],"w") do io;JSON3.write(io,summary);end
end
