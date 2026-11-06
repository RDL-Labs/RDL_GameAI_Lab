using Test
include("../../src/lw/LW.jl")
@testset "shortage, felt anxiety, and self provision" begin
 s=LW.food_security_state();s["required"]=4.
 s["H"]=.5;@test LW.food_anxiety(s)==0;@test !LW.food_request_ready(s,0)
 s["H"]=1.1;small=LW.food_anxiety(s);@test 0<small<.01
 s["H"]=3.;@test LW.food_anxiety(s)>small
 s["estimate"]=LW.D("search_seconds"=>100.,"metabolic_rate"=>.01);s["supplied"]=0.
 body=LW.Body(10.,0.,90.,0.)
 choice=LW.D("technique"=>"pickup","ref"=>"tree","seconds"=>100.,"uncertainty"=>0.)
 ac=LW.acquisition_state();ac["choice"]=choice;map=LW.D("acquisition"=>ac)
 good=LW.food_self_reliance(s,map,body);@test good["confidence"]==1
 choice["seconds"]=10000.;@test LW.food_self_reliance(s,map,body)["confidence"]<good["confidence"]
 choice["seconds"]=100.;ac["methods"]["pickup"]=LW.D("H"=>4.)
 @test LW.food_self_reliance(s,map,body)["confidence"]<good["confidence"]
 @test LW.food_self_reliance(s,map,LW.Body(10.,0.,60.,0.))["confidence"]==0
 s["H"]=0.;s["body_shortfall"]=.1;@test LW.food_request_ready(s,0)
 @test LW.food_request_considered!(s,0);@test !LW.food_request_ready(s,1)
 rel=LW.social_relations_state("npc_a";relational=true);rel["food_security"]=s
 s["self_reliance"]=good
 pressure=LW.social_aid_pressure(LW.social_aid_state("npc_a"))
 _,strong=LW.select_target(["npc_b"],LW.D(),pressure;relation=rel,seed="same")
 s["self_reliance"]=LW.D("confidence"=>0.)
 _,weak=LW.select_target(["npc_b"],LW.D(),pressure;relation=rel,seed="same")
 @test strong["probabilities"][1]<weak["probabilities"][1]
 @test strong["probabilities"][1]>0
end
