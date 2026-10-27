include(joinpath(@__DIR__,"native.jl"))
using Test
using Random
@testset "prepared obstacle geometry matches direct rays" begin
 rng=MersenneTwister(20261027)
 cases=Any[Any[],Any[(x=0.,z=13.,radius=1.,height=1.),
     (x=1.,z=5.,radius=1.,height=2.),(x=0.,z=0.,radius=2.,height=.999)]]
 for _ in 1:50
     push!(cases,Any[(x=40rand(rng)-20,z=40rand(rng)-20,radius=2rand(rng),height=2rand(rng)) for _ in 1:30])
 end
 for objects in cases, yaw in (0.,45.,179.5,360.)
     position=(0.,0.);observed=lateral_obstacles(objects,position,yaw,"check")
     distances=Float64[]
     for angle in -90:30:90
         sn,cs=sincos(deg2rad(yaw+angle));best=Inf
         for o in objects
             o.height>=1 || continue
             d=RDLMigrationProbe.ray_hit(position,(sn,cs),RDLMigrationProbe.Circle(o.x,o.z,o.radius))
             d!==nothing && d<=12 && (best=min(best,d))
         end
         push!(distances,best)
     end
     @test [r["distance"] for r in observed["samples"]]==[isfinite(d) ? d : 12. for d in distances]
     @test [r["status"] for r in observed["samples"]]==[isfinite(d) ? "hit" : "clear" for d in distances]
 end
end
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
