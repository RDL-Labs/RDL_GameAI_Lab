include(joinpath(@__DIR__,"mb_completion_reward_checks.jl"))
@testset "configured home rest value and delayed credit" begin
 s,p=route_fixture();loop=BasicLoop("home");loop.H=0.
 candidate=D("method"=>"approach","action"=>"walk","priority"=>1.,"question"=>"target_observed")
 choose_method!(loop,[candidate],"arrive")
 resolve_method!(loop,"arrive",true,true;completion_reward=1.)
 configured_home_rest_arrival!(s,loop,"arrive",0)
 configured_home_rest_arrival!(s,loop,"later",1_000_000)
 @test s["configured_home_rest_reward"]["arrival"]["source"]=="arrive"
 for i in 0:58
  @test configured_home_rest_step!(s,loop,true,"rest","performed",i*1_000_000,17280_000_000)==0
 end
 @test configured_home_rest_step!(s,loop,true,"rest","performed",59_000_000,17280_000_000)==5
 @test loop.methods["approach"].reward==6 && loop.H==0
 @test configured_home_rest_step!(s,loop,true,"rest","performed",59_000_000,17280_000_000)==0
 @test configured_home_rest_step!(s,loop,false,"walk","performed",60_000_000,17280_000_000)==0
 @test s["configured_home_rest_reward"]["arrival"]===nothing
 for i in 61:125
  configured_home_rest_step!(s,loop,true,"rest","performed",i*1_000_000,17280_000_000)
 end
 @test s["configured_home_rest_reward"]["reward_total"]==5
 # No reward outside home, interrupted rest, or for passive recovery while scanning.
 for (home,action,status) in ((false,"rest","performed"),(true,"scan","performed"),(true,"rest","blocked"))
  fresh=mb_map_state("a")
  for i in 0:65;configured_home_rest_step!(fresh,loop,home,action,status,i*1_000_000,17280_000_000);end
  @test fresh["configured_home_rest_reward"]["reward_total"]==0
 end
 fresh=mb_map_state("a")
 for i in 0:29;configured_home_rest_step!(fresh,loop,true,"rest","performed",i*1_000_000,17280_000_000);end
 configured_home_rest_step!(fresh,loop,true,"walk","performed",30_000_000,17280_000_000)
 for i in 31:60;configured_home_rest_step!(fresh,loop,true,"rest","performed",i*1_000_000,17280_000_000);end
 @test fresh["configured_home_rest_reward"]["reward_total"]==0
 for i in 0:59;configured_home_rest_step!(s,loop,true,"rest","performed",17280_000_000+i*1_000_000,17280_000_000);end
 @test s["configured_home_rest_reward"]["reward_total"]==10
 @test loop.methods["approach"].reward==6 # Old arrival was cleared on departure.
 route,plan=route_fixture();id=plan["mb_route"]
 mb_record!(route,merge(plan,D("purpose_family"=>"home")),"performed",.01,3_000_000)
 mb_observe!(route,chunk_view(4_000_000,"mid"),4_000_000)
 next=only(mb_route_candidates!(route,move,"home",90.,0.,4_000_000))
 mb_record!(route,merge(next,D("purpose_family"=>"home")),"performed",.01,4_000_000)
 mb_observe!(route,chunk_view(5_000_000,"near"),5_000_000;home=true)
 mb_route_goal!(route,"home","op:4000000:a",true,0.,0.,5_000_000;completion_reward=1.)
 @test mb_goal_result!(route,"home","op:4000000:a",true,0.,0.,5_000_000;completion_reward=1.)
 configured_home_rest_arrival!(route,loop,"op:4000000:a",5_000_000)
 chunk=only(values(route["chunks"]));before=chunk["successes"];earned=chunk["reward"]
 for i in 5:64;configured_home_rest_step!(route,loop,true,"rest","performed",i*1_000_000,17280_000_000);end
 @test route["routes"]["stats"][id]["rest_reward"]==5
 @test route["routes"]["stats"][id]["success"]==1
 @test chunk["reward"]==earned+5 && chunk["rest_reward"]==5
 @test chunk["successes"]==before # Rest reward does not invent another arrival.
end
