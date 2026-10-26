include(joinpath(@__DIR__,"mb_chunk_checks.jl"))
function route_fixture()
 s=mb_map_state("a";chunks=true);chunk_trip!(s,0)
 mb_goal_result!(s,"home","op:1000000:a",true,8,0,2_000_000)
 mb_observe!(s,chunk_view(3_000_000,"far"),3_000_000)
 p=only(mb_chunk_candidates!(s,move,"home",90.,0.,3_000_000))
 s,p
end
@testset "whole path execution and parent outcome" begin
 s,p=route_fixture();id=p["mb_route"]
 @test length(p["mb_path"])==2 && p["mb_route_index"]==1
 mb_record!(s,merge(p,D("purpose_family"=>"home")),"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 @test s["routes"]["active"]["cursor"]==2
 q=only(mb_route_candidates!(s,move,"home",90.,0.,4_000_000))
 @test q["mb_route"]==id && q["mb_edge"]==p["mb_path"][2]
 mb_record!(s,merge(q,D("purpose_family"=>"home")),"performed",.01,4_000_000)
 mb_observe!(s,chunk_view(5_000_000,"near"),5_000_000;home=true)
 @test s["routes"]["active"]["cursor"]==3
 @test get(s["routes"]["stats"][id],"success",0)==0
 mb_route_goal!(s,"food","op:4000000:a",true,8,0,5_000_000)
 @test s["routes"]["active"]!==nothing
 mb_route_goal!(s,"home","op:4000000:a",true,8,0,5_000_000)
 @test s["routes"]["active"]===nothing
 @test s["routes"]["stats"][id]["success"]==1 && s["routes"]["stats"][id]["reward"]==8
 @test last(s["routes"]["events"])["steps"]==2
 mb_route_goal!(s,"home","op:4000000:a",true,8,0,5_000_000)
 @test s["routes"]["stats"][id]["reward"]==8
end
@testset "route interruptions and unresolved endpoints" begin
 for reason in ("blocked","interrupted","unresolved")
  s,p=route_fixture();id=p["mb_route"]
  mb_record!(s,p,reason=="blocked" ? "blocked" : "performed",.01,3_000_000)
  if reason=="interrupted"
   mb_route_candidates!(s,move,"food",90.,0.,3_000_000)
  elseif reason=="unresolved"
   mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
   q=only(mb_route_candidates!(s,move,"home",90.,0.,4_000_000))
   mb_record!(s,q,"performed",.01,4_000_000)
   mb_observe!(s,chunk_view(5_000_000,"near"),5_000_000)
   @test isempty(mb_route_candidates!(s,move,"home",90.,0.,5_000_000))
  end
  if reason=="blocked"
   @test s["routes"]["active"]["uncertain"]
   @test s["routes"]["uncertainty"]["execution_blocked"]==1
  elseif reason=="unresolved"
   @test s["routes"]["active"]["uncertain"]
   mb_route_record!(s,D("action"=>"walk","mb_control"=>"change","mb_control_H"=>8),"performed",5_000_000)
   @test s["routes"]["stats"][id][reason]==1
  else
   @test s["routes"]["active"]===nothing
   @test s["routes"]["stats"][id][reason]==1
  end
  @test s["routes"]["stats"][id]["reward"]==0
 end
end
@testset "shared path identity and tentative progress" begin
 s,p=route_fixture();id=p["mb_route"]
 for kind in ("sleep","wake")
  q=mb_route_attach!(D("priority"=>3.),s,p["mb_path"],"home",kind)
  @test q["mb_route"]==id
 end
 mb_record!(s,p,"performed",.01,3_000_000)
 # A single observed feature permits a tentative step but cannot verify it.
 obs=chunk_view(4_000_000,"mid");resize!(obs["features"],1)
 mb_observe!(s,obs,4_000_000)
 @test s["routes"]["active"]["cursor"]==2
 @test s["routes"]["active"]["verified"]==0
 @test s["routes"]["stats"][id]["reward"]==0
 q=only(mb_route_candidates!(s,move,"home",90.,0.,4_000_000))
 mb_record!(s,q,"performed",.01,4_000_000)
 mb_observe!(s,chunk_view(5_000_000,"near"),5_000_000)
 mb_route_candidates!(s,move,"home",90.,0.,5_000_000)
 mb_route_record!(s,D("action"=>"walk","mb_control"=>"change","mb_control_H"=>8),"performed",5_000_000)
 q=mb_route_attach!(D("priority"=>3.),s,p["mb_path"],"home","wake")
 @test q["priority"]<3
 @test s["routes"]["stats"][id]["unresolved"]==1
end
@testset "endpoint acquisition and recognition contradiction" begin
 s,p=route_fixture();path=p["mb_path"]
 p=mb_route_attach!(deepcopy(p),s,path,"food","chunk")
 mb_record!(s,p,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 q=only(mb_route_candidates!(s,move,"food",90.,0.,4_000_000))
 mb_record!(s,q,"performed",.01,4_000_000)
 mb_observe!(s,chunk_view(5_000_000,"near"),5_000_000)
 mb_record!(s,D("action"=>"pickup","purpose_family"=>"food"),"picked_up",0.,5_000_000)
 mb_observe!(s,chunk_view(6_000_000,"near"),6_000_000)
 mb_route_goal!(s,"food","op:5000000:a",true,8,0,6_000_000)
 @test s["routes"]["stats"][p["mb_route"]]["success"]==1
 @test last(s["routes"]["events"])["steps"]==2
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 obs=chunk_view(4_000_000,"near");obs["features"][2]["range_band"]="near"
 mb_observe!(s,obs,4_000_000)
 @test s["routes"]["active"]["uncertain"]
 @test s["routes"]["uncertainty"]["recognition_mismatch"]==1
end
@testset "H controls route alternatives without a candidate-count vote" begin
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 q=only(mb_route_candidates!(s,move,"home",90.,0.,4_000_000))
 alt=D("method"=>"other","action"=>"walk","priority"=>q["priority"],"question"=>"target_observed")
 loop=BasicLoop("home";probabilistic=true)
 low=mb_route_control!(s,deepcopy(Any[q,alt]),loop,"home",4_000_000)
 lowmass=last(s["routes"]["decisions"])["mass"]
 @test lowmass["continue"]>.99 && lowmass["change"]>0
 loop.H=8
 high=mb_route_control!(s,deepcopy(Any[q,alt]),loop,"home",4_000_000)
 highmass=last(s["routes"]["decisions"])["mass"]
 @test highmass["change"]>lowmass["change"] && highmass["recheck"]>lowmass["recheck"]
 many=Any[deepcopy(q)];append!(many,[merge(alt,D("method"=>"other$i")) for i in 1:20])
 mb_route_control!(s,many,loop,"home",4_000_000)
 @test last(s["routes"]["decisions"])["mass"]["change"]≈highmass["change"]
 @test loop.H==8 && s["routes"]["active"]!==nothing
 choice=only(filter(p->p["mb_control"]=="recheck",high))
 mb_record!(s,choice,"performed",0.,4_000_000)
 @test s["routes"]["active"]["cursor"]==2
 mb_record!(s,only(filter(p->p["mb_control"]=="change",high)),"performed",0.,5_000_000)
 @test s["routes"]["active"]===nothing
 @test last(s["routes"]["events"])["reason"]=="H_choice"
 @test last(s["routes"]["events"])["H"]==8
end
@testset "missing observation retains route and reacquires tentatively" begin
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid";partial=true),4_000_000)
 @test s["routes"]["active"]["uncertain"] && s["routes"]["active"]["cursor"]==1
 @test isempty(mb_route_candidates!(s,move,"home",90.,0.,4_000_000;H=2))
 loop=BasicLoop("home";probabilistic=true);loop.H=2
 plans=mb_route_control!(s,Any[],loop,"home",4_000_000)
 @test only(plans)["mb_control"]=="recheck"
 mb_record!(s,only(plans),"performed",0.,4_000_000)
 mb_observe!(s,chunk_view(5_000_000,"mid"),5_000_000)
 q=only(mb_route_candidates!(s,move,"home",90.,0.,5_000_000;H=3))
 @test q["mb_route_index"]==2 && s["routes"]["active"]["verified"]==0
 @test s["routes"]["uncertainty"]["reacquired"]==1
 @test s["routes"]["stats"][p["mb_route"]]["reward"]==0
 mb_record!(s,D("action"=>"rest","purpose_family"=>"home"),"performed",0.,5_000_000)
 @test s["routes"]["active"]!==nothing
 # Ordinary movement evidence must not resolve parent H.
 probe=BasicLoop("home";probabilistic=true);probe.H=3
 choose_method!(probe,[D("method"=>"walk","priority"=>1.,"question"=>"movement_progress")],"op:test")
 resolve_method!(probe,"op:test",true,false)
 @test probe.H==4 && probe.methods["walk"].reward==0
end
