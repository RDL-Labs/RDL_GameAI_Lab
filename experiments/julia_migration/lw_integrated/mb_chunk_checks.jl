include(joinpath(@__DIR__,"native.jl"))
using Test
function chunk_view(now,band;partial=false)
 D("source"=>"ob:$now:a","coverage"=>partial ? "partial" : "complete","features"=>[
 D("color"=>"brown","azimuth"=>[-5.,5.],"range_band"=>band,"distance"=>5.),
 D("color"=>"gray","azimuth"=>[40.,50.],"range_band"=>"far","distance"=>20.)])
end
walk=D("action"=>"walk","direction"=>0,"purpose_family"=>"home")
move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
function chunk_trip!(s,t)
 mb_observe!(s,chunk_view(t,"far"),t)
 mb_record!(s,walk,"performed",.01,t)
 mb_observe!(s,chunk_view(t+1_000_000,"mid"),t+1_000_000)
 mb_record!(s,walk,"performed",.01,t+1_000_000)
 mb_observe!(s,chunk_view(t+2_000_000,"near"),t+2_000_000;home=true)
end
@testset "goal H credited chunks" begin
 s=mb_map_state("a";chunks=true);chunk_trip!(s,0)
 @test length(s["route_trace"])==2 && isempty(s["chunks"])
 @test !mb_goal_result!(s,"home","op:1000000:a",false,8,9,2_000_000)
 @test isempty(s["chunks"])
 @test mb_goal_result!(s,"home","op:1000000:a",true,8,0,2_000_000)
 @test s["chunk_reward"]==8 && s["chunk_formations"]==1
 @test !mb_goal_result!(s,"home","op:1000000:a",true,8,0,2_000_000)
 @test s["chunk_reward"]==8
 c=only(values(s["chunks"]));@test c["successes"]==1 && length(c["edges"])==2
 chunk_trip!(s,3_000_000)
 @test mb_goal_result!(s,"home","op:4000000:a",true,4,0,5_000_000)
 @test c["successes"]==2 && c["reward"]==12 && length(s["chunks"])==1
 chunk_trip!(s,6_000_000)
 @test mb_goal_result!(s,"home","op:7000000:a",true,0,0,8_000_000)
 @test c["reward"]==12 && c["successes"]==3
 mb_observe!(s,chunk_view(9_000_000,"far"),9_000_000)
 # Include both origin and intermediate entry alternatives in this lifecycle test.
 cs=mb_chunk_candidates!(s,move,"home",90.,0.,9_000_000;H=8)
 @test length(cs)==1 && cs[1]["mb_depth"]==2 && s["searches"]==0
 @test isempty(mb_chunk_candidates!(s,move,"food",90.,0.,9_000_000))
 @test isempty(mb_chunk_candidates!(s,move,"home",10.,0.,9_000_000))
 p=merge(cs[1],D("purpose_family"=>"home"));e=s["edges"][p["mb_edge"]];before=mb_edge_cost(e)
 mb_record!(s,p,"performed",.01,9_000_000)
 mb_observe!(s,chunk_view(10_000_000,"mid"),10_000_000)
 @test c["matches"]==1 && e["matches"]==1 && mb_edge_cost(e)<before
 @test c["reward"]==12 # Prediction success is not purpose reward.
 cs2=mb_route_candidates!(s,move,"home",90.,0.,10_000_000)
 @test length(cs2)==1 && cs2[1]["mb_chunk_index"]==2
 mb_record!(s,merge(cs2[1],D("purpose_family"=>"home")),"blocked",.01,10_000_000)
 mb_observe!(s,chunk_view(11_000_000,"mid"),11_000_000)
 @test c["misses"]==0 && c["execution_failures"]==1 && c["reward"]==12 && isempty(s["route_trace"])
 mb_forget_node!(s,c["from"])
 @test isempty(s["chunks"])
end
@testset "unknown and wrong purpose do not form chunks" begin
 s=mb_map_state("a";chunks=true);chunk_trip!(s,0)
 @test !mb_goal_result!(s,"food","op:1000000:a",true,8,0,2_000_000)
 @test isempty(s["chunks"])
 chunk_trip!(s,3_000_000)
 mb_record!(s,walk,"performed",.01,5_000_000)
 mb_observe!(s,chunk_view(6_000_000,"near";partial=true),6_000_000;home=true)
 @test !mb_goal_result!(s,"home","op:5000000:a",true,8,0,6_000_000)
 @test isempty(s["chunks"]) && isempty(s["route_trace"])
end
