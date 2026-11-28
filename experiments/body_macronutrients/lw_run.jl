# Fresh full-LW integration, no inherited serialized Digestion layout.
using JSON3, Test
length(ARGS) in (2,3) || error("usage: lw_run.jl INPUT OUTPUT [DAYS]")
const run_days=length(ARGS)==3 ? parse(Int,ARGS[3]) : 3
run_days>0 || error("positive days required")
const repo=normpath(joinpath(@__DIR__,"../.."))
const out=abspath(ARGS[2])
ispath(out) && error("fresh output required")
mkpath(out)
const input=JSON3.read(read(ARGS[1],String),Dict{String,Any})
input["config"]["days"]=run_days
input["scene"]["macronutrient_body"]=true
input["scene"]["wildlife"]=Dict("enabled"=>false)
input["config"]["digestion"]="ordinary"
const source=joinpath(out,"source")
mkpath(joinpath(source,"integrations"))
cp(joinpath(repo,"src"),joinpath(source,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(source,"integrations/lightweight_julia"))
const roster=Tuple(get(input["scene"],"experimental_actor_ids",["npc_a","npc_b","npc_c"]))
write(joinpath(source,"src/data/lw_actor_ids.jl"),"const IDS="*repr(roster)*"\n")
write(joinpath(out,"input.json"),JSON3.write(input))
cp(@__FILE__,joinpath(out,"runner.jl"))
println("Fresh LW; $run_days days; actors=$roster; wildlife OFF; macro body ON; existing training/settings retained.")
flush(stdout)
include(joinpath(source,"integrations/lightweight_julia/native.jl"))
const timing=@timed native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--checkpoint-dir",joinpath(out,"checkpoints")])
const result=JSON3.read(read(joinpath(out,"run/result.json"),String))
@testset "full LW nutrition" begin
    @test length(result.daily)==run_days
    @test length(result.digestion)==length(roster)
    for actor in roster
        physiology=result.digestion[Symbol(actor)]
        @test haskey(physiology,:macronutrients)
        @test abs(physiology.energy_residual)<1e-6
        @test physiology.macronutrients.ingested≈RDLBody.MEAL_ENERGY*physiology.eaten
        @test physiology.macronutrients.spent>0
        physical=physiology.macronutrients
        actor_index=findfirst(==(actor),roster)
        expected_initial=232input["scene"]["reserve"][actor_index]/100+108
        @test physical.energy+physical.spent+physical.conversion_loss+physical.excreted-physical.ingested≈expected_initial
    end
end
write(joinpath(out,"completed.json"),JSON3.write((days=run_days,seconds=timing.time,bytes=timing.bytes,gctime=timing.gctime,digestion=result.digestion)))
