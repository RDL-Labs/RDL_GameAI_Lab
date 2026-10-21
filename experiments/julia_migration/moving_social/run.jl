# Compatibility entry; canonical implementation is in src or integrations.
include(joinpath(@__DIR__, "../../../src/lw/simulation/moving.jl"))
if abspath(PROGRAM_FILE) == @__FILE__
    specs=JSON3.read(read(ARGS[1],String));report=D("boundaries"=>contact_boundaries(specs[1]),"scenarios"=>D())
    for spec in specs
        value=moving_scenario(spec);@assert value==moving_scenario(spec);report["scenarios"][spec.name]=value
    end
    open(ARGS[2],"w") do io
        JSON3.write(io,report)
    end
end
