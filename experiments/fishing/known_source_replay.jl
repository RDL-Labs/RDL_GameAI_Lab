using JSON3, Serialization, SHA, Test
length(ARGS)==2 || error("usage: known_source_replay.jl BASE40 NEW_OUTPUT")
const base=abspath(ARGS[1]);const out=abspath(ARGS[2])
ispath(out) && error("fresh output required")
mkpath(out);cp(joinpath(base,"source"),joinpath(out,"source"))
const input=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any})
input["config"]["days"]=19
write(joinpath(out,"input.json"),JSON3.write(input))
const replay_identity=deepcopy(input);delete!(replay_identity["config"],"days")
const root=joinpath(out,"source/src")
const files=sort([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
const oldcode=bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
# Deliberate single-file migration on an experiment copy, not the original checkpoint.
for path in ("lw/decision/acquisition.jl",)
 cp(joinpath(@__DIR__,"../../src",path),joinpath(root,path);force=true)
end
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
const original=checkpoint_load(joinpath(base,"checkpoints/day-018.jls"),replay_identity,oldcode,19)
serialize(joinpath(out,"resume-day-018.jls"),merge(original,(code=checkpoint_code_hash(),)))
write(joinpath(out,"migration.json"),JSON3.write((oldcode,newcode=checkpoint_code_hash(),changed=["src/lw/decision/acquisition.jl"],checkpoint_day=18)))
println("Replay day 18 state -> day 19; known-source discovery fix; all four actors; inherited rewards retained.");flush(stdout)
const timing=@timed native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",joinpath(out,"resume-day-018.jls"),"--checkpoint-dir",joinpath(out,"checkpoints")])
const result=JSON3.read(read(joinpath(out,"run/result.json"),String))
@testset "replay nutrition" begin
 @test length(result.daily)==19
 for dig in values(result.digestion)
  @test abs(dig.energy_residual)<1e-6
 end
end
write(joinpath(out,"completed.json"),JSON3.write((days=19,start_day=18,seconds=timing.time,bytes=timing.bytes,gctime=timing.gctime)))

