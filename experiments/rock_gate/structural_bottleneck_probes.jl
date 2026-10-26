using Test
include("../julia_migration/lw_integrated/mb_chunk_checks.jl")
@testset "structural bottleneck probes (current behavior, not desired behavior)" begin
 # 1. An old unresolved debt has no new increment, and is treated as within estimate.
 s=mb_map_state("a");p=D("action"=>"scan")
 mb_parent_begin!(s,p,"home",nothing,0);a=s["parent_mb"]["active"]["home"]
 a["charged"]=4.;a["child_debt"]=4.
 mb_parent_record!(s,p,0.,0)
 inc=mb_parent_H_increment!(s,"home","op:0:a",false,1_000_000)
 @test inc==0 && a["charged"]==4
 @test forecast_method_evidence(inc,false,true,false)===nothing
 # 2. Fixed: verified achievement forms a chunk even with zero pressure/reward.
 s=mb_map_state("a";chunks=true);chunk_trip!(s,0)
 @test length(s["route_trace"])==2
 @test mb_goal_result!(s,"home","op:1000000:a",true,0.,0.,2_000_000)
 @test length(s["chunks"])==1 && isempty(s["route_trace"])
 # 3. Even a known usable path is not considered below the H threshold.
 s=mb_map_state("a";chunks=true);chunk_trip!(s,0)
 origin=mb_scene(chunk_view(0,"far")).key
 mb_observe!(s,chunk_view(3_000_000,"far"),3_000_000)
 @test mb_search(s,origin,"home",3_000_000).solution!==nothing
 @test isempty(mb_simulate!(s,move,"home",0.,2.,90.,0.,3_000_000))
 # 4. Once two distinct scenes were seen, later stagnation is never evaluated as such.
 s=mb_map_state("a");mb_parent_begin!(s,p,"home",nothing,0);a=s["parent_mb"]["active"]["home"]
 a["scenes"]=["old_scene_1","old_scene_2"];a["actions"]=200
 mb_parent_record!(s,p,0.,0)
 @test mb_parent_H_increment!(s,"home","op:0:a",false,1_000_000)==0
 @test last(s["parent_mb"]["records"])["stagnation"]==0
 # 5. The latest ambiguous appearance overwrites earlier home evidence.
 s=mb_map_state("a");mb_observe!(s,chunk_view(0,"far"),0;home=true)
 key=s["current"].key;@test s["nodes"][key]["home"]
 mb_observe!(s,chunk_view(1_000_000,"far"),1_000_000;home=false)
 @test s["current"].key==key && !s["nodes"][key]["home"]
end
