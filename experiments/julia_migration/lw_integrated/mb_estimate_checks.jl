include(joinpath(@__DIR__,"mb_route_checks.jl"))
@testset "forecast residual rather than unfinished goal" begin
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 estimate=deepcopy(s["routes"]["active"]["estimate"])
 @test estimate["actions"]==2 && estimate["energy"]≈.02
 inc=mb_route_H_increment!(s,"home","op:3000000:a",false,4_000_000)
 @test inc==0
 loop=BasicLoop("home";probabilistic=true);loop.H=3
 choose_method!(loop,[D("method"=>"walk","priority"=>1.,"question"=>"target_observed")],"op:3000000:a")
 resolve_method!(loop,"op:3000000:a",nothing,false;goal_H_increment=inc)
 @test loop.H==3 && loop.methods["walk"].reward==0 && loop.methods["walk"].failure_count==0
 @test mb_route_H_increment!(s,"food","op:3000000:a",false,4_000_000)===nothing
 q=only(mb_route_candidates!(s,move,"home",90.,0.,4_000_000))
 mb_record!(s,q,"performed",.01,4_000_000)
 mb_observe!(s,chunk_view(5_000_000,"near"),5_000_000)
 @test mb_route_H_increment!(s,"home","op:4000000:a",false,5_000_000)==0
 # Rechecks eventually exceed the frozen goal estimate, not the first unfinished tick.
 for t in 5:7
  mb_route_record!(s,D("action"=>"scan","mb_recheck"=>p["mb_route"]),"performed",t*1_000_000;energy=0.)
  inc=mb_route_H_increment!(s,"home","op:$(t*1_000_000):a",false,(t+1)*1_000_000)
  @test inc==(t==5 ? 0 : 1)
  @test mb_route_H_increment!(s,"home","op:$(t*1_000_000):a",false,(t+1)*1_000_000)==inc
 end
 @test s["routes"]["active"]["estimate"]==estimate
 before=deepcopy(s["routes"]["active"]["effort"])
 mb_route_record!(s,D("action"=>"rest","purpose_family"=>"home"),"performed",9_000_000;energy=.5)
 @test s["routes"]["active"]["effort"]==before
end
@testset "energy and contradiction residuals, actual success only" begin
 s,p=route_fixture();mb_record!(s,p,"performed",.08,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 @test mb_route_H_increment!(s,"home","op:3000000:a",false,4_000_000)>0
 @test s["routes"]["stats"][p["mb_route"]]["reward"]==0
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 obs=chunk_view(4_000_000,"near");obs["features"][2]["range_band"]="near"
 mb_observe!(s,obs,4_000_000)
 @test mb_route_H_increment!(s,"home","op:3000000:a",false,4_000_000)==1
 @test s["routes"]["active"]["effort"]["contradictions"]==1
 # True goal resolution resets H and alone releases its reward.
 loop=BasicLoop("home";probabilistic=true);loop.H=5
 choose_method!(loop,[D("method"=>"home","priority"=>1.,"question"=>"home_confirmed")],"op:goal")
 resolve_method!(loop,"op:goal",true,true;goal_H_increment=0)
 @test loop.H==0 && loop.methods["home"].reward==5
 @test_throws ErrorException resolve_method!(loop,"op:bad",false,false;goal_H_increment=-1)
end
@testset "zero H goal still ends the route without reward" begin
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 mb_route_goal!(s,"home","op:3000000:a",true,0,0,4_000_000)
 @test s["routes"]["active"]===nothing
 @test last(s["routes"]["events"])["outcome"]=="success" && last(s["routes"]["events"])["reward"]==0
end
