using Test, Serialization
include("../../src/body/RDLBody.jl")
using .RDLBody
@testset "LW nutrition bridge" begin
    partial=Digestion(macronutrients=true,reserve=70.)
    @test partial.macro_body.body.tissue==RDLBody.MACRO_PARAMETERS.tissue_target
    @test partial.macro_body.body.sugar≈22.4 && partial.macro_body.body.fat≈140
    g=Digestion(macronutrients=true)
    b=HumanBody(g.macro_body.body,g.macro_body.hours_per_second)
    energy_before=RDLBody.Macronutrients.nutrient_energy(g.macro_body.body)
    ingest!(g,1,body_energy(b),0)
    @test g.macro_body.body.gut==RDLBody.FOOD_NUTRIENT_ENERGY[1]
    @test RDLBody.Macronutrients.nutrient_energy(g.macro_body.body)≈energy_before+20
    @test body_energy(b)==290 # ingestion does not immediately supply usable energy
    direct=deepcopy(g.macro_body.body)
    RDLBody.Macronutrients.advance!(direct,RDLBody.MACRO_PARAMETERS,1/720;intensity=.65)
    stepped=RDLBody.step(b,"walk",0)[1]
    b=digest!(g,stepped,1.;action="walk")
    @test g.macro_body.body.spent≈direct.spent
    @test g.macro_body.body.sugar≈direct.sugar
    @test abs(digestion_snapshot(g)["energy_residual"])<1e-8
    for _ in 1:5; ingest!(g,1,body_energy(b),0); end
    @test !can_ingest(g)
    @test taste(g,1,body_energy(b))>=0
    @test_throws ErrorException ingest!(g,1,body_energy(b),0)
    for _ in 1:17280; b=digest!(g,b,1.;sleeping=true); end
    @test abs(digestion_snapshot(g)["energy_residual"])<1e-6
    buf=IOBuffer();serialize(buf,(g,b));seekstart(buf);restored,rb=deserialize(buf)
    b=digest!(g,b,1.;sleeping=true); rb=digest!(restored,rb,1.;sleeping=true)
    @test body_energy(b)==body_energy(rb)
    @test digestion_snapshot(g)==digestion_snapshot(restored)
    awake=Digestion(macronutrients=true);awake.macro_body.body.tissue=90
    asleep=deepcopy(awake)
    digest!(awake,HumanBody(awake.macro_body.body,awake.macro_body.hours_per_second),720.;sleeping=false);digest!(asleep,HumanBody(asleep.macro_body.body,asleep.macro_body.hours_per_second),720.;sleeping=true)
    @test asleep.macro_body.body.repaired>awake.macro_body.body.repaired
    legacy=Digestion();ingest!(legacy,1,80.,0)
    @test digest!(legacy,Body(1.,0.,80.,0.),1800.).reserve==100
    @test digestion_snapshot(legacy)["absorbed"]==20
    @test RDLBody.meal_energy(legacy)==20
    @test RDLBody.meal_energy(g)≈20
end

include("../../src/lw/LW.jl")
@testset "macro demand and food forecasts" begin
    gut=LW.Digestion(macronutrients=true)
    body=LW.Body(1.,0.,50.,0.)
    legacy=LW.Digestion()
    @test LW.trade_food_need(body,gut,zeros(Int,8))≈30/(20)
    @test LW.trade_food_need(body,legacy,zeros(Int,8))≈1.5
    hunger=LW.hunger_state("npc_a")
    LW.hunger_update!(hunger,"npc_a",0,100.;body_demand=.3)
    @test hunger["intensity"]==.3
    LW.hunger_expect!(hunger,"home",0,100.,100.,1.)
    LW.hunger_update!(hunger,"npc_a",1_000_000,100.;body_demand=.3)
    @test hunger["forecast"]!==nothing # fuel fullness must not erase nutrient demand
    LW.hunger_update!(hunger,"npc_a",2_000_000,100.;body_demand=0.)
    @test hunger["forecast"]===nothing
end
