using Test
include("../../src/lw/LW.jl")
@testset "fishing lesson scopes" begin
 for receipt in ("picked_up","no_catch")
  q=LW.configured_fishing_training_state()
  @test LW.configured_fishing_training_plan(q,Int[],true,true,[])["action"]=="retrieve"
  @test LW.configured_fishing_training_plan(q,[LW.RDLBody.FISH_FOOD],true,false,[])["action"]=="process_food"
  @test LW.configured_fishing_training_plan(q,[LW.RDLBody.COOKED_FISH],true,false,[])["action"]=="rest"
  LW.configured_fishing_training_result!(q,"eat","ate",1,true,1)
  @test q["stage"]=="taste"
  LW.configured_fishing_training_result!(q,"eat","ate",LW.RDLBody.COOKED_FISH,true,2;liking=1.5)
  @test q["stage"]=="trial"
  LW.configured_fishing_training_result!(q,"fish","fishing",0,false,3)
  @test q["stage"]=="trial"
  LW.configured_fishing_training_result!(q,"fish",receipt,0,false,4)
  @test q["stage"]=="return"
  LW.configured_fishing_training_result!(q,"walk","performed",0,true,5)
  @test q["stage"]=="completed"
  @test LW.configured_fishing_training_plan(q,[5],true,true,[])===nothing
  LW.configured_fishing_training_result!(q,"fish",receipt,0,true,6)
  @test length(q["records"])==3
 end
end
