using Test
include("../../src/lw/LW.jl")
@testset "signed food value in social approach" begin
 w=LW.world(true);a="npc_a";w.positions[a]=(0.,0.);w.positions["npc_b"]=(0.,4.)
 view=LW.social_sight(w,a,0.,0)
 move=LW.evaluate_movement(LW.EnergyMovementPolicy(),LW.perceive_movement(w,a,LW.D(a=>0.),Any[],Int[]))
 relation=LW.social_relations_state(a);loop=LW.BasicLoop("food";probabilistic=true,seed=1)
 values=fill(1.,length(LW.RDLBody.FOOD_KIND_IDS));values[6]=-8.
 @test isempty(LW.social_approach_candidates(view,move,relation,loop,0;food_value=sum(values)/length(values),food_values=values))
 values[1]=20.
 @test !isempty(LW.social_approach_candidates(view,move,relation,loop,0;food_values=values))
 @test isempty(LW.social_approach_candidates(view,move,relation,loop,0;food_value=-1.))
 values[1]=NaN
 @test_throws ErrorException LW.social_approach_candidates(view,move,relation,loop,0;food_values=values)
end
@testset "aid records negative received value" begin
 s=LW.social_aid_state("npc_a")
 trial=LW.social_aid_begin!(s,"negative","npc_b",0;probability=1.,values=[1.,-4.],expected_kind=2)
 @test trial["expected"]==-4.
 result=LW.social_aid_finish!(s,"negative","npc_b","given",1;received_kind=2)
 @test result["actual"]==-4.
 @test s["pending"]===nothing
end
