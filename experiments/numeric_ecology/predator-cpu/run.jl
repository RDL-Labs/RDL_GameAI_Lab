using JSON3
include("Predators.jl")
spec=JSON3.read(read(joinpath(@__DIR__,"map-spec.json"),String))
for (name,enabled,seed) in (("control",false,20261005),("predator",true,20261005),("replay",true,20261005),("seed2",true,20261006),("seed3",true,20261007))
    out=joinpath(@__DIR__,name)
    m=@timed Predators.simulate(spec;predator=enabled,seed,out)
    metrics=(seconds_including_compilation=m.time,allocated_bytes=m.bytes,process_peak_rss_bytes=Sys.maxrss())
    write(joinpath(out,"metrics.json"),JSON3.write(metrics))
    println(JSON3.write((run=name,metrics=metrics,daily=m.value.daily)))
end
@assert read(joinpath(@__DIR__,"predator","result.json"))==read(joinpath(@__DIR__,"replay","result.json"))
println("Deterministic replay matched")
