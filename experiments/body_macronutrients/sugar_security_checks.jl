using Test
include("../../integrations/lightweight_julia/native.jl")
@testset "sugar provisioning; fat emergency reserve" begin
 b=RDLBody.HumanBody(RDLBody.Macronutrients.MacroBody(sugar=20.,fat=100.),1/720.)
 @test food_security_buffer(b)==20.
 before=body_spendable(b,70.)
 b.nutrients.fat=300.
 @test food_security_buffer(b)==20.
 @test body_spendable(b,70.)≈before+200
 b.nutrients.sugar=0.
 @test food_security_buffer(b)==0.
 @test body_alive(b)
 function forecast(body)
  state=food_security_state()
  food_security_update!(state,nothing,body,nothing,zeros(Int,8),Int[],0.,0,17_280_000_000)
 end
 low=forecast(b)
 b.nutrients.sugar=30.
 high=forecast(b)
 @test low["required"]>high["required"]
 b.nutrients.fat=0.
 @test forecast(b)["required"]==high["required"]
 @test food_security_buffer(Body(10.,0.,90.,0.))==20.
end
