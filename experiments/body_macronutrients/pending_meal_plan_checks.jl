using Test
include("../../src/lw/LW.jl")
@testset "satisfied eating request does not start a new meal" begin
 g=LW.Digestion(macronutrients=true)
 b=g.macro_body.body;b.sugar=15.;b.fat=180.;b.amino=0.
 human=LW.HumanBody(b,g.macro_body.hours_per_second)
 LW.RDLBody.Macronutrients.feed!(b,(15.,6.,20.),LW.RDLBody.MACRO_PARAMETERS)
 @test LW.food_physical_demand(g,LW.body_energy(human))>0
 @test LW.food_eating_demand(g,LW.body_energy(human))==0
 # No world lookup/candidate construction is needed for a satisfied request.
 map=LW.D()
 @test LW.food_desire_plan!(map,nothing,nothing,"npc_a",g,human,true,zeros(Int,8),(),(0.,0.),0;requested=true)===nothing
 @test map["food_desire"]["intent"]===nothing
end
