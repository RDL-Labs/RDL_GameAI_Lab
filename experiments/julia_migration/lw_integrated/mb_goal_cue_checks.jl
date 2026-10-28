include("mb_join_checks.jl")
function goal_cue_fixture()
 s=mb_map_state("a";chunks=true);s["navigation_mode"]="goal_cues"
 chunk_trip!(s,0);mb_goal_result!(s,"home","op:1000000:a",true,8,0,2_000_000)
 for e in values(s["edges"]);e["offset"]=0.;end # Successful movement toward the brown cue.
 mb_observe!(s,chunk_view(3_000_000,"far"),3_000_000)
 # No hidden positions; the pool is just what was visually observed.
 pool=(items=[D("key"=>"cue:shape:brown:0","kind"=>"shape","label"=>"brown","angle"=>0.)],dropped=0)
 p=D("method"=>"cue:shape:brown:0","action"=>"walk","priority"=>2.5)
 s,pool,p
end
@testset "goal relations bias visible cues without join subgoal" begin
 s,pool,p=goal_cue_fixture()
 out=mb_goal_cue_project!(s,[copy(p)],pool,"home",8,3_000_000);q=only(out)
 @test q["priority"]>p["priority"]
 @test q["mb_goal_cue"]["goal"]=="home"
 @test !haskey(q,"mb_join") && !haskey(q,"mb_route") && !haskey(q,"mb_edge")
 @test only(mb_goal_cue_project!(s,[copy(p)],pool,"food",8,3_000_000))["priority"]==p["priority"]
 c=only(values(s["chunks"]));c["successes"]+=10
 stronger=only(mb_goal_cue_project!(s,[copy(p)],pool,"home",8,3_000_000))
 @test stronger["priority"]>q["priority"]
 c["misses"]+=10
 weaker=only(mb_goal_cue_project!(s,[copy(p)],pool,"home",8,3_000_000))
 @test weaker["priority"]<q["priority"]
 away=deepcopy(pool);away.items[1]["angle"]=180.
 @test only(mb_goal_cue_project!(s,[copy(p)],away,"home",8,3_000_000))["priority"]<weaker["priority"]
 @test only(mb_goal_cue_project!(s,[merge(p,D("action"=>"scan"))],pool,"home",8,3_000_000))["priority"]==p["priority"]
 @test only(mb_goal_cue_project!(s,[copy(p)],pool,"home",8,4_000_000))["priority"]==p["priority"]
 credits=s["chunk_goal_credits"];mb_goal_cue_selected!(s,q,3_000_000)
 @test s["goal_cues"]["selected"]==1 && s["chunk_goal_credits"]==credits
 @test s["routes"]["active"]===nothing
 s["navigation_mode"]="explicit_join"
 @test only(mb_goal_cue_project!(s,[copy(p)],pool,"home",8,3_000_000))["priority"]==p["priority"]
 s,_=join_fixture();s["navigation_mode"]="goal_cues"
 @test isempty(mb_simulate!(s,move,"home",0,2,90.,0.,5_000_000))
 ps=mb_simulate!(s,move,"home",8,2,90.,0.,5_000_000)
 @test !isempty(ps) && all(!haskey(x,"mb_join") for x in ps)
 # Pruned knowledge cannot leave a synthetic connection in the derived cache.
 s,pool,p=goal_cue_fixture();mb_goal_cue_project!(s,[copy(p)],pool,"home",8,3_000_000)
 empty!(s["edges"])
 @test only(mb_goal_cue_project!(s,[copy(p)],pool,"home",8,3_000_000))["priority"]==p["priority"]
end
