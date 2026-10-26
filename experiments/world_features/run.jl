using JSON3
include("../../src/ecology/herbivore/Herbivores.jl")
spec=JSON3.read(read(joinpath(@__DIR__,"../numeric_ecology/herbivore-cpu/map-spec.json"),String))
out=abspath(ARGS[1]);ispath(out) && error("fresh output required")
measured=@timed Herbivores.simulate(spec;rich=true,days=3,out)
open(joinpath(out,"metrics.json"),"w") do io
 JSON3.write(io,(seconds=measured.time,allocated_bytes=measured.bytes,peak_rss_bytes=Sys.maxrss(),rich=true,seed=20261005))
end
println(JSON3.write(measured.value.daily))
