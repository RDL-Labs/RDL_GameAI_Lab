using Test
include("../../integrations/lightweight_julia/native.jl")
@testset "sugar candidate forecast" begin
 b=RDLBody.HumanBody(RDLBody.Macronutrients.MacroBody(sugar=10.,fat=100.),1/720.)
 state=D("estimate"=>D("samples"=>1,"metabolic_rate"=>.01))
 before=deepcopy(b.nutrients)
 short=food_sugar_forecast(b,state,100.)
 long=food_sugar_forecast(b,state,4000.)
 @test short["penalty"]==0
 @test long["penalty"]>0
 @test long["required"]==40
 @test long["pending_sugar"]==0
 b.nutrients.fat=300.
 @test food_sugar_forecast(b,state,4000.)==long
 b.nutrients.gut=(20.,0.,20.)
 pending=food_sugar_forecast(b,state,100.)
 @test pending["pending_sugar"]≈1.25
 @test food_sugar_forecast(b,state,100000.)["pending_sugar"]==20.
 @test b.nutrients.gut==(20.,0.,20.)
 @test b.nutrients.sugar==before.sugar
 @test food_sugar_forecast(b,state,4000.;uncertainty=1.)["penalty"]>food_sugar_forecast(b,state,4000.)["penalty"]
 @test food_sugar_forecast(Body(10.,0.,90.,0.),state,100.)===nothing
end
