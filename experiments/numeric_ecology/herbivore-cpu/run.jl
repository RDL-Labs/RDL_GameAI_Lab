using JSON3
include("Herbivores.jl")
spec=JSON3.read(read(joinpath(@__DIR__,"map-spec.json"),String))
out=length(ARGS)>0 ? ARGS[1] : joinpath(@__DIR__,"run")
measurement=@timed Herbivores.simulate(spec;out)
r=measurement.value
metrics=(seconds_including_compilation=measurement.time,allocated_bytes=measurement.bytes,peak_rss_bytes=Sys.maxrss(),agents=r.agents,days=r.days,agent_updates=r.agent_updates)
open(joinpath(out,"metrics.json"),"w") do io;JSON3.write(io,metrics);end
println(JSON3.write(metrics))
println(JSON3.write(r.daily))
