include(joinpath(@__DIR__,"mb_parent_checks.jl"))
@testset "signed prediction reward and achievement evidence" begin
 e=D("expected_actions"=>100.,"upper_actions"=>200.,"expected_energy"=>1.,"energy"=>2.)
 reward(t,c)=mb_completion_reward(e,t,c)["value"]
 @test reward(100,1)==1
 @test reward(95,.95)==1
 @test reward(50,.5)>reward(80,.8)>reward(100,1)>reward(150,1.5)>reward(1000,10) >= .25
 @test reward(0,0)<=1.75
 @test reward(50,1)>reward(100,1)
 @test reward(100,.5)>reward(100,1)
 s=mb_map_state("a");p=D("action"=>"scan")
 mb_parent_begin!(s,p,"home",nothing,0)
 frozen=deepcopy(s["parent_mb"]["active"]["home"]["estimate"])
 mb_parent_record!(s,p,.01,0)
 @test mb_parent_reward(s,"home","op:0:a",1_000_000)===nothing
 @test mb_parent_H_increment!(s,"home","op:0:a",true,1_000_000)==0
 r=mb_parent_reward(s,"home","op:0:a",1_000_000)
 @test r==mb_completion_reward(frozen,1,.01)["value"]
 @test last(s["parent_mb"]["records"])["estimate"]==frozen
 @test mb_parent_reward(s,"food","op:0:a",1_000_000)===nothing
 @test mb_parent_reward(s,"home","op:1:a",1_000_000)===nothing
 @test mb_parent_reward(s,"home","op:0:a",2_000_000)===nothing
 @test mb_parent_H_increment!(s,"home","op:0:a",true,1_000_000)===nothing
 @test s["parent_mb"]["successes"]==1
 for h in (0.,32.)
  loop=BasicLoop("home");loop.H=h
  candidate=D("method"=>"route","priority"=>1.,"question"=>"goal","action"=>"walk")
  choose_method!(loop,[candidate],"arrival")
  @test resolve_method!(loop,"arrival",true,true;completion_reward=r)
  @test loop.methods["route"].reward==r
  @test !resolve_method!(loop,"arrival",true,true;completion_reward=r)
  @test_throws Exception resolve_method!(loop,"arrival",true,true;completion_reward=r+1)
 end
 for bad in (-1.,Inf,NaN,true)
  @test_throws Exception resolve_method!(BasicLoop("home"),"bad",true,true;completion_reward=bad)
 end
 @test_throws Exception resolve_method!(BasicLoop("home"),"bad",false,false;completion_reward=1.)
 chunk=mb_map_state("a";chunks=true);chunk_trip!(chunk,0)
 @test mb_goal_result!(chunk,"home","op:1000000:a",true,0.,4.,2_000_000;completion_reward=.25)
 @test only(values(chunk["chunks"]))["reward"]==.25
 @test only(values(chunk["chunks"]))["successes"]==1
 route,plan=route_fixture()
 mb_record!(route,merge(plan,D("purpose_family"=>"home")),"performed",.01,3_000_000)
 mb_observe!(route,chunk_view(4_000_000,"mid"),4_000_000;home=true)
 mb_route_goal!(route,"home","op:3000000:a",true,0.,4.,4_000_000;completion_reward=.25)
 @test route["routes"]["outcomes"]["success"]==1
 @test last(route["routes"]["events"])["reward"]==.25
end
