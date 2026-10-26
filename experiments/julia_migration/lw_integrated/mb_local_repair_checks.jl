include(joinpath(@__DIR__,"mb_censored_checks.jl"))
@testset "local correction preserves parent and reconnects one step" begin
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 a=s["routes"]["active"];original=deepcopy(a["estimate"]);path=copy(a["path"]);id=a["id"]
 repair=D("action"=>"walk","direction"=>0,"purpose_family"=>"home","mb_control"=>"repair","mb_local_repair"=>id)
 mb_record!(s,repair,"performed",.02,4_000_000)
 @test s["routes"]["active"]===a && a["cursor"]==2 && a["repair_pending"]
 mb_observe!(s,chunk_view(5_000_000,"mid"),5_000_000)
 @test a["cursor"]==2 && !a["repair_pending"]
 @test only(mb_route_candidates!(s,move,"home",90.,0.,5_000_000))["mb_route_index"]==2
 mb_record!(s,deepcopy(repair),"performed",.02,5_000_000)
 mb_observe!(s,chunk_view(6_000_000,"near"),6_000_000)
 @test a["cursor"]==3 && a["verified"]==1 # only the original first step was verified
 @test a["path"]==path && a["estimate"]==original && a["id"]==id
 @test s["routes"]["started"]==1 && isempty(s["routes"]["outcomes"])
 @test a["effort"]["actions"]==3 && a["effort"]["energy"]≈.05
 @test s["routes"]["local_repairs"]==2 && s["routes"]["local_rejoins"]==2
 mb_route_goal!(s,"home","op:5000000:a",true,5,0,6_000_000)
 @test last(s["routes"]["events"])["outcome"]=="success"
end
@testset "ambiguous local correction costs time without fake progress" begin
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 a=s["routes"]["active"]
 for t in 4:9
  repair=D("action"=>"walk","direction"=>0,"purpose_family"=>"home","mb_control"=>"repair","mb_local_repair"=>a["id"])
  mb_record!(s,repair,"performed",.01,t*1_000_000)
  mb_observe!(s,chunk_view((t+1)*1_000_000,"far"),(t+1)*1_000_000)
 end
 @test a["cursor"]==2 && a["repair_pending"]
 @test isempty(mb_route_candidates!(s,move,"home",90.,0.,10_000_000))
 @test mb_route_H_increment!(s,"home","op:9000000:a",false,10_000_000)>0
 @test s["routes"]["stats"][a["id"]]["reward"]==0
 loop=BasicLoop("home";probabilistic=true);loop.H=32
 plans=mb_route_control!(s,Any[],loop,"home",10_000_000)
 abandon=only(filter(p->haskey(p,"mb_abandon"),plans))
 mb_record!(s,abandon,"performed",0.,10_000_000)
 @test s["routes"]["active"]===nothing && last(s["routes"]["events"])["outcome"]=="abandoned"
 @test last(s["routes"]["events"])["local_repairs"]==6
end
@testset "inherited H does not alone discard a new route" begin
 s,p=route_fixture();mb_record!(s,p,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 q=only(mb_route_candidates!(s,move,"home",90.,0.,4_000_000))
 loop=BasicLoop("home";probabilistic=true);loop.H=32
 alt=D("method"=>"avoid","action"=>"walk","priority"=>q["priority"],"question"=>"target_observed")
 plans=mb_route_control!(s,deepcopy(Any[q,alt]),loop,"home",4_000_000)
 low=last(s["routes"]["decisions"])["mass"]["change"]
 @test low<.001 && any(p->p["mb_control"]=="repair",plans)
 s["routes"]["active"]["effort"]["charged"]=16
 mb_route_control!(s,deepcopy(Any[q,alt]),loop,"home",4_000_000)
 @test last(s["routes"]["decisions"])["mass"]["change"]>low
 # A real parent purpose switch still interrupts the route.
 @test isempty(mb_route_candidates!(s,move,"food",90.,0.,4_000_000))
 @test last(s["routes"]["events"])["reason"]=="parent_purpose_changed"
end
