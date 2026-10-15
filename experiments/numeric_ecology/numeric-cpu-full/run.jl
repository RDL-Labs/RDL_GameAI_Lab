using JSON3, Serialization
include("NumericCore.jl")
using .NumericCore
include("registry.jl")
NumericCore.AGENT_COUNT[]=parse(Int,get(ENV,"NUMERIC_AGENT_COUNT","3"))
1<=NumericCore.AGENT_COUNT[]<=30 || error("NUMERIC_AGENT_COUNT must be in 1..30")
include("source/lw_integrated/run.jl")
include("source/lw_integrated/checks.jl")
spec=length(ARGS)>=1 ? ARGS[1] : joinpath(@__DIR__,"../numeric-cpu/parity-spec.json")
out=length(ARGS)>=2 ? ARGS[2] : joinpath(@__DIR__,"result.json")
input=encode(JSON3.read(read(spec,String)))
all(length(getproperty(input.scene,key))==length(IDS) for key in (:positions,:reserve,:initial_inventory)) || error("agent count and scene arrays must agree")
@assert audit(input)==0
measurement=@timed run_integrated(input)
r,s=measurement.value
validate_integrated(r,input)
string_count=audit((r,s))
@assert string_count==0
@assert all(iszero,NumericCore.AUDITS)
open(out,"w") do io; JSON3.write(io,decode(r)); end
serialize(out*".numeric.bin",(version=1,registry=NumericCore.BYTES,result=r,summary=s))
report=(seconds=measurement.time,allocated_bytes=measurement.bytes,agents=length(IDS),days=input.config.days,
    live_state_strings=NumericCore.AUDITS,output_strings=string_count,registry_entries=length(NumericCore.BYTES),
    registry_bytes=sum(length,NumericCore.BYTES))
open(out*".metrics.json","w") do io; JSON3.write(io,report); end
println(JSON3.write(report))
