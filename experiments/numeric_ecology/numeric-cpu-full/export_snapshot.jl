# Read a numeric result snapshot in a fresh process and export human-readable JSON.
# This snapshot preserves results/MBs, not the full suspended execution stack.
using Serialization, JSON3
include("NumericCore.jl")
using .NumericCore
include("registry.jl")
include("source/lw_integrated/run.jl")
length(ARGS)==2 || error("usage: export_snapshot.jl INPUT.numeric.bin OUTPUT.json")
snapshot=deserialize(ARGS[1])
snapshot.version==1 || error("unsupported numeric snapshot version")
n=length(NumericCore.BYTES)
length(snapshot.registry)>=n && snapshot.registry[1:n]==NumericCore.BYTES || error("registry/schema mismatch")
for bytes in snapshot.registry[n+1:end]; NumericCore.intern(bytes); end
audit(snapshot.result)==0 || error("text unexpectedly present in numeric snapshot")
open(ARGS[2],"w") do io; JSON3.write(io,decode(snapshot.result)); end
println("numeric snapshot restored and exported")
