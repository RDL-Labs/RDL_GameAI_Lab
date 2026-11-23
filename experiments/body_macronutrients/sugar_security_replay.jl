using JSON3, Serialization, SHA, Test
length(ARGS)==2 || error("usage: sugar_security_replay.jl BASE10 NEW_OUTPUT")
const base=abspath(ARGS[1]);const out=abspath(ARGS[2])
ispath(out) && error("fresh output required")
mkpath(out);cp(joinpath(base,"source"),joinpath(out,"source"))
const input=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any})
input["config"]["days"]=9
write(joinpath(out,"input.json"),JSON3.write(input))
const replay_identity=deepcopy(input);delete!(replay_identity["config"],"days")
const root=joinpath(out,"source/src")
const files=sort([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
const oldcode=bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
# Deliberate single-file migration on an experiment copy, not the original checkpoint.
cp(joinpath(@__DIR__,"../../src/lw/decision/food_security.jl"),joinpath(root,"lw/decision/food_security.jl");force=true)
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
const original=checkpoint_load(joinpath(base,"checkpoints/day-008.jls"),replay_identity,oldcode,9)
serialize(joinpath(out,"resume-day-008.jls"),merge(original,(code=checkpoint_code_hash(),)))
write(joinpath(out,"migration.json"),JSON3.write((oldcode,newcode=checkpoint_code_hash(),changed="src/lw/decision/food_security.jl",checkpoint_day=8)))
println("Replay same day 8 state -> day 9; sugar provisioning, fat retained for survival; all four actors.");flush(stdout)
const timing=@timed native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",joinpath(out,"resume-day-008.jls"),"--checkpoint-dir",joinpath(out,"checkpoints")])
const result=JSON3.read(read(joinpath(out,"run/result.json"),String))
@testset "replay nutrition" begin
 @test length(result.daily)==9
 for dig in values(result.digestion)
  @test abs(dig.energy_residual)<1e-6
 end
end
write(joinpath(out,"completed.json"),JSON3.write((days=9,start_day=8,seconds=timing.time,bytes=timing.bytes,gctime=timing.gctime)))
