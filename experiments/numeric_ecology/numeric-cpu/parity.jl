using JSON3, Test
include(joinpath(@__DIR__,ARGS[1],"lw_integrated","run.jl"))
input=JSON3.read(read(joinpath(@__DIR__,"parity-spec.json"),String))
measurement=@timed run_integrated(input)
r,s=measurement.value
include(joinpath(@__DIR__,ARGS[1],"lw_integrated","checks.jl"))
validate_integrated(r,input)
open(joinpath(@__DIR__,ARGS[1]*"-result.json"),"w") do io; JSON3.write(io,r); end
println("seconds=",measurement.time," allocated_bytes=",measurement.bytes)
