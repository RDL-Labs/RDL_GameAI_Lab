include("mb_chunk_checks.jl")
@testset "successful route channels and intermediate entry" begin
 s=mb_map_state("a";chunks=true);chunk_trip!(s,0)
 @test mb_goal_result!(s,"home","op:1000000:a",true,8,0,2_000_000)
 c=only(values(s["chunks"]));id=only(keys(s["chunks"]));whole=copy(c["edges"])
 mb_observe!(s,chunk_view(3_000_000,"mid"),3_000_000)
 cs=mb_chunk_candidates!(s,move,"home",90.,0.,3_000_000;H=8)
 p=only(cs)
 @test p["mb_chunk"]==id && p["mb_chunk_index"]==2
 @test p["mb_path"]==whole[2:end] && p["mb_route_index"]==1
 @test p["mb_depth"]==1 && c["edges"]==whole
 before=p["priority"];depth=mb_chunk_depth(c)
 c["successes"]+=1
 @test mb_chunk_depth(c)>depth
 @test only(mb_chunk_candidates!(s,move,"home",90.,0.,3_000_000;H=8))["priority"]>before
 depth=mb_chunk_depth(c);c["execution_failures"]=1
 @test mb_chunk_depth(c)<depth
 c["execution_failures"]=0
 # Joining is not achievement and must not award credit.
 credits=s["chunk_goal_credits"]
 mb_record!(s,merge(p,D("purpose_family"=>"home")),"performed",.01,3_000_000)
 a=s["routes"]["active"]
 @test a["path"]==whole[2:end] && a["chunk_start_index"]==2
 @test a["estimate"]["steps"]==1 && s["chunk_goal_credits"]==credits
 @test only(mb_route_candidates!(s,move,"home",90.,0.,3_000_000;H=8))["mb_chunk_index"]==2
 @test isempty(mb_chunk_candidates!(s,move,"food",90.,0.,3_000_000;H=8))
 # Retrieval strength must not alter the learned geometric agreement.
 targets=collect(keys(s["nodes"]));strength=Dict(k=>100. for k in targets)
 normal=mb_correspondences(s,targets,3_000_000;H=32)
 weighted=mb_correspondences(s,targets,3_000_000;H=32,retrieval_strength=strength)
 @test [(x["key"],x["confidence"]) for x in normal]==[(x["key"],x["confidence"]) for x in weighted]
 chosen=last(sort(targets));strong=Dict(chosen=>100.)
 narrow=mb_correspondences(s,targets,3_000_000;H=0,retrieval_strength=strong)
 @test first(narrow)["key"]==chosen
 broad=mb_correspondences(s,targets,3_000_000;H=32,retrieval_strength=strong)
 @test length(broad)>length(narrow)
end
