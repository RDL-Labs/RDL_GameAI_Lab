include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "finite obstacle observation and lateral candidate boundary" begin
 obs=lateral_obstacles([(x=0.,z=4.,radius=1.,height=2.)],(0.,0.),0.,"ob:a")
 @test length(obs["items"])<=7
 @test all(Set(keys(x))==Set(["ref","forward","right"]) for x in obs["items"])
 @test any(x->x["forward"]==3 && x["right"]==0,obs["items"])
 @test isempty(lateral_obstacles([(x=0.,z=-4.,radius=1.,height=2.)],(0.,0.),0.,"s")["items"])
 ground=D("coverage"=>"complete","output_limited"=>false,"samples"=>[D("direction_deg"=>a,"status"=>a==0 ? "blocked" : "sampled","height_delta"=>a==0 ? nothing : 0.) for a in ANGLES])
 move=D("movement_surface"=>D("ground"=>ground),"food_coverage"=>"complete","visible"=>Any[])
 emptyobs=D("coverage"=>"complete","output_limited"=>false,"items"=>Any[])
 candidates=[D("action"=>"walk","direction"=>i,"priority"=>1.,"method"=>"s$i") for i in (1,3)]
 trace=project_lateral!(candidates,move,emptyobs,"left",nothing)
 @test trace["applied"]
 @test candidates[1]["priority"]>candidates[2]["priority"]
 @test length(candidates)==2
 move["food_coverage"]="partial";before=deepcopy(candidates)
 @test !project_lateral!(candidates,move,emptyobs,"right",nothing)["applied"]
 @test before==candidates
 move["food_coverage"]="complete"
 @test lateral_terrain(move,emptyobs)["directional_samples"][3]["total"]===nothing
 # Equal totals must not hide opposing model/physical contributions.
 terrain=lateral_terrain(move,emptyobs)
 terrain["minimum_directions"]=[-45,45]
 terrain["directional_samples"][2]["model_field_cost"]=-.2
 terrain["directional_samples"][2]["physical"]=.2
 @test !(-45 in composed_lateral_bias(terrain,"left")["lateral"]["eligible"])
 running=[D("action"=>"run","direction"=>1,"priority"=>1.,"method"=>"run")]
 before=deepcopy(running);project_lateral!(running,move,emptyobs,"left",nothing)
 @test running==before
 @test_throws ErrorException native_main([mktempdir(),"--lateral-side","neutral"])
end
