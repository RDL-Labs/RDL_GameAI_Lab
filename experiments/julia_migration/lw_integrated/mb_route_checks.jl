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
  @test s["routes"]["active"]===nothing
  @test s["routes"]["stats"][id][reason]==1
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
 @test s["routes"]["active"]===nothing
 @test s["routes"]["stats"][p["mb_route"]]["mismatch"]==1
end
