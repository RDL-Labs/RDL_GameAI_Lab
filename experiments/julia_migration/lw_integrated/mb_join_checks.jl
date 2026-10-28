include("mb_channel_checks.jl")
function join_fixture()
 s=mb_map_state("a";chunks=true);chunk_trip!(s,0)
 mb_goal_result!(s,"home","op:1000000:a",true,8,0,2_000_000)
 unknown=deepcopy(chunk_view(3_000_000,"far"))
 unknown["features"][1]["color"]="purple";unknown["features"][2]["color"]="yellow"
 mb_observe!(s,unknown,3_000_000);start=s["current"].key
 mb_record!(s,walk,"performed",.01,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"far"),4_000_000)
 unknown["source"]="ob:5000000:a";mb_observe!(s,unknown,5_000_000)
 s,start
end
@testset "join a known channel without seeing the parent goal" begin
 s,start=join_fixture();t=mb_channel_terminals(s,"home")
 @test !haskey(t,start) && isempty(mb_channel_terminals(s,"food"))
 direct=mb_search(s,start,"home",5_000_000)
 joined=mb_search(s,start,"home",5_000_000;terminals=t)
 @test joined.solution.path==direct.solution.path
 @test joined.expanded<direct.expanded
 @test joined.solution.bridge_length==1
 @test !s["nodes"][joined.solution.join_node]["home"]
 cs=mb_simulate!(s,move,"home",0,2,90.,0.,5_000_000)
 p=only(cs);@test p["mb_route_kind"]=="channel_join"
 @test p["mb_join"]["stage"]=="approach" && p["mb_join"]["estimate"]["steps"]==1
 @test !haskey(p,"mb_chunk") # Bridge failure must not punish the successful suffix.
 credits=s["chunk_goal_credits"]
 mb_record!(s,merge(p,D("purpose_family"=>"home")),"performed",.01,5_000_000)
 a=s["routes"]["active"];estimate=deepcopy(a["estimate"])
 mb_observe!(s,chunk_view(6_000_000,"far"),6_000_000)
 q=only(mb_route_candidates!(s,move,"home",90.,0.,6_000_000))
 @test a["join"]["stage"]=="follow" && q["mb_chunk_index"]==1
 @test a["estimate"]==estimate && a["goal"]=="home"
 @test s["chunk_goal_credits"]==credits && get(s["routes"]["stats"][a["id"]],"success",0)==0
 @test q["mb_route"]==p["mb_route"] && q["mb_route_index"]==2
 # Parent switch, body gate and cooldown remain effective.
 @test isempty(mb_simulate!(s,move,"home",8,2,90.,0.,6_000_000))
 @test isempty(mb_route_candidates!(s,move,"food",90.,0.,6_000_000))
 s,start=join_fixture();@test isempty(mb_simulate!(s,move,"home",8,2,10.,0.,5_000_000))
 # No fabricated bridge, stale suffix, or reward for an unobserved join.
 bridge=only(k for (k,e) in s["edges"] if e["from"]==start)
 delete!(s["edges"],bridge)
 @test mb_search(s,start,"home",5_000_000;terminals=mb_channel_terminals(s,"home")).solution===nothing
 c=only(values(s["chunks"]));delete!(s["edges"],last(c["edges"]))
 @test isempty(mb_channel_terminals(s,"home"))
 s,start=join_fixture();p=only(mb_simulate!(s,move,"home",0,2,90.,0.,5_000_000))
 mb_record!(s,p,"performed",.01,5_000_000);a=s["routes"]["active"];a["cursor"]=2
 @test !mb_route_join_update!(s,a,5_000_000)
 @test a["join"]["stage"]=="approach" && a["chunk"]===nothing
end
