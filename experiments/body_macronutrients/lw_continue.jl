using JSON3, Test
length(ARGS)==3 || error("usage: lw_continue.jl BASE NEW_OUTPUT TOTAL_DAYS")
const base=abspath(ARGS[1]);const out=abspath(ARGS[2]);const days=parse(Int,ARGS[3])
const previous=JSON3.read(read(joinpath(base,"completed.json"),String)).days
days>previous || error("total days must exceed completed days")
ispath(out) && error("fresh output required")
const checkpoint=joinpath(base,"checkpoints","day-"*lpad(previous,3,'0')*".jls")
isfile(checkpoint) || error("missing checkpoint")
mkpath(out)
cp(joinpath(base,"source"),joinpath(out,"source"))
const input=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any})
input["config"]["days"]=days
write(joinpath(out,"input.json"),JSON3.write(input))
cp(@__FILE__,joinpath(out,"runner.jl"))
println("Continue frozen LW day $previous -> $days; no retraining or condition changes.");flush(stdout)
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
const timing=@timed native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",checkpoint,"--checkpoint-dir",joinpath(out,"checkpoints")])
const result=JSON3.read(read(joinpath(out,"run/result.json"),String))
@testset "continued LW nutrition" begin
 @test length(result.daily)==days
 for actor in input["scene"]["experimental_actor_ids"]
  physiology=result.digestion[Symbol(actor)]
  @test abs(physiology.energy_residual)<1e-6
  @test physiology.macronutrients.ingested≈RDLBody.MEAL_ENERGY*physiology.eaten
 end
end
write(joinpath(out,"completed.json"),JSON3.write((days,start_day=previous,seconds=timing.time,bytes=timing.bytes,gctime=timing.gctime)))
