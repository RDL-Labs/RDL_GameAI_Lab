# Compatibility entry; canonical implementation is in src or integrations.
include(joinpath(@__DIR__, "../../../src/lw/simulation/social.jl"))
if abspath(PROGRAM_FILE) == @__FILE__
    specs=JSON3.read(read(ARGS[1],String))
    report=D("boundaries"=>boundaries(),"scenarios"=>D())
    for spec in specs
        value=scenario(spec);@assert value==scenario(spec)
        report["scenarios"][spec.name]=value
    end
    open(ARGS[2],"w") do io
        JSON3.write(io,report)
    end
end
