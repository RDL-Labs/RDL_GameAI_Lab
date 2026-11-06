using Test
D(args...)=Dict{String,Any}(args...)
include("../../src/lw/configured_paths/acorn_quest.jl")
include("../../src/lw/configured_paths/home_observation.jl")
@testset "training food focus preserves perception and releases" begin
 q=configured_acorn_quest_state()
 visible=[D("appearance"=>"red_round_fruit","ref"=>0),D("appearance"=>"brown_capped_ovoid","ref"=>1)]
 @test only(configured_acorn_quest_food_targets(q,visible))["ref"]==1
 @test length(visible)==2
 @test isempty(configured_acorn_quest_food_targets(q,visible[1:1]))
 q["stage"]="completed"
 @test configured_acorn_quest_food_targets(q,visible)===visible
end
@testset "observation ends without a final sensing tick" begin
 s=configured_observation_state((0.,0.))
 m=D("nodes"=>D("a"=>D("home"=>true)),"edges"=>D(),"chunk_formations"=>0)
 configured_observation_finish!(s,m)
 @test s["completed"]
 @test s["ticks"]==0 && s["valid_views"]==0
 @test s["map_at_end"]["home_nodes"]==1
end
@testset "acorn quest evidence and lifecycle" begin
 q=configured_acorn_quest_state();day=17280000000
 @test configured_acorn_quest_request!(q,false,day,day,true,[])===nothing
 @test configured_acorn_quest_request!(q,true,day-1,day,true,[])===nothing
 @test configured_acorn_quest_request!(q,true,day,day,true,[])===false
 configured_acorn_quest_result!(q,"deposit","performed",day+1;delivered=["initial"])
 @test q["stage"]=="outbound"
 configured_acorn_quest_request!(q,true,day+2,day,false,[D("appearance"=>"brown_capped_ovoid","distance"=>1.)])
 @test q["arrived"]
 configured_acorn_quest_result!(q,"pickup","not_found",day+3;kind=3,source="x")
 @test q["stage"]=="outbound"
 configured_acorn_quest_result!(q,"pickup","picked_up",day+4;kind=3,source="x")
 @test q["stage"]=="return"
 @test configured_acorn_quest_request!(q,true,day+5,day,true,[])===true
 @test q["returned"] && q["completed_us"]===nothing
 configured_acorn_quest_result!(q,"deposit","performed",day+6;delivered=["initial"])
 @test q["stage"]=="return"
 configured_acorn_quest_result!(q,"deposit","performed",day+7;delivered=["x","x"])
 @test q["stage"]=="completed" && q["delivered"]==1
 @test configured_acorn_quest_finished_plan(q)["action"]=="rest"
end
@testset "tasting stages require actual results" begin
 q=configured_acorn_quest_state(;tasting=true);q["stage"]="outbound";q["arrived"]=true
 configured_acorn_quest_result!(q,"pickup","picked_up",1;kind=3,source="x")
 @test q["stage"]=="outbound"
 configured_acorn_quest_result!(q,"pickup","picked_up",2;kind=3,source="x")
 @test length(q["acquired_sources"])==1
 configured_acorn_quest_result!(q,"pickup","picked_up",3;kind=3,source="y")
 @test q["stage"]=="return"
 configured_acorn_quest_result!(q,"deposit","performed",4;delivered=["x","y"])
 @test q["stage"]=="taste_raw" && q["completed_us"]===nothing
 @test configured_acorn_quest_training_plan(q,[],false,true,true)===nothing
 @test configured_acorn_quest_training_plan(q,[1],true,true,true)["food_kind"]==3
 @test configured_acorn_quest_training_plan(q,[3],true,false,true)["action"]=="rest"
 configured_acorn_quest_result!(q,"eat","ate",5;kind=1,liking=.5)
 @test q["stage"]=="taste_raw"
 configured_acorn_quest_result!(q,"eat","gut_full",6;kind=3)
 @test q["stage"]=="taste_raw"
 configured_acorn_quest_result!(q,"eat","ate",7;kind=3,liking=-.5)
 @test q["stage"]=="process"
 @test configured_acorn_quest_training_plan(q,[3],true,true,false)["action"]=="rest"
 configured_acorn_quest_result!(q,"process_food","processing",8)
 @test q["stage"]=="process"
 configured_acorn_quest_result!(q,"process_food","processed",9)
 @test q["stage"]=="taste_processed"
 configured_acorn_quest_result!(q,"eat","ate",10;kind=4,liking=.2)
 @test q["stage"]=="taste_fruit" && q["completed_us"]===nothing
 configured_acorn_quest_result!(q,"eat","ate",11;kind=1,liking=.4)
 @test q["stage"]=="completed" && q["completed_us"]==11
end
