using Test, JSON3
include("../julia_migration/lw_integrated/mb_chunk_checks.jl")
@testset "harvest observation, competition and local credit" begin
 s=mb_map_state("a";chunks=true);s["daily_plan"]=mb_daily_plan_state("a",9)
 mb_plan_context!(s,0,600_000_000,80.,0.)
 visible=D("visible"=>[D("ref"=>0,"distance"=>1.)])
 mb_daily_request!(s,visible,nothing,false,0,80.,0.,0,600_000_000)
 a=s["daily_plan"]["active"];p=D("action"=>"pickup","food_ref"=>0)
 mb_daily_result!(s,p,"picked_up",0,.1,0;acquired_source="op:0:a")
 mb_food_contact!(s,p,"picked_up",1,1_000_000,"op:0:a")
 @test s["food_sites"][0]["state"]=="remaining"
 @test a["strategy"]=="acquire" && a["acquired"]==1
 rival=mb_map_state("rival");mb_food_contact!(rival,p,"picked_up",0,2_000_000,"op:1000000:rival")
 @test rival["food_sites"][0]["state"]=="empty"
 @test s["food_sites"][0]["state"]=="remaining" # Unseen competition doesn't leak.
 mb_food_contact!(s,p,"not_found",nothing,3_000_000,"op:2000000:a")
 @test s["food_sites"][0]["observed_us"]==1_000_000
 @test a["strategy"]=="acquire" # Not reachable is not depletion evidence.
 mb_food_contact!(s,p,"not_found",0,4_000_000,"op:3000000:a")
 @test a["strategy"]=="explore" && !a["closed"]
 @test a["acquired"]==1 && a["energy"]≈.1 && a["started_us"]==0
 @test s["food_sites"][0]["knowledge"]=="last_observed"
 mb_daily_request!(s,visible,nothing,false,1,80.,0.,5_000_000,600_000_000)
 @test a["strategy"]=="acquire" && !mb_food_site_empty(s,0)
 mb_daily_stage!(s["daily_plan"],"known_food",5_000_000;reason="test_acquisition")
 mb_daily_result!(s,p,"picked_up",5_000_000,.1,1;acquired_source="op:5000000:a")
 mb_food_contact!(s,p,"picked_up",0,6_000_000,"op:5000000:a")
 @test a["strategy"]=="explore" && a["stage"]=="return" && a["acquired"]==2
 @test !a["closed"] && a["delivered"]==0
 @test last(s["daily_plan"]["plan_records"])["reason"]=="harvest_exhausted"
 @test !last(s["daily_plan"]["plan_records"])["completed"] # Harvest isn't roundtrip success.
 @test any(x->x["completed"] && x["reason"]=="acquired",s["daily_plan"]["models"]["known_food"])
 mb_daily_result!(s,D("action"=>"deposit"),"performed",7_000_000,.1,2;delivered_sources=["op:0:a","op:5000000:a"])
 @test only(s["daily_plan"]["records"])["food_success"]
 @test a["delivered"]==2
end
@testset "food site binding changes expectation, not route success" begin
 s=mb_map_state("a";chunks=true)
 walk["purpose_family"]="food"
 chunk_trip!(s,0)
 mb_food_site_observe!(s,7,0,2_000_000,"harvest_contact";operation="op:1000000:a")
 @test mb_goal_result!(s,"food","op:1000000:a",true,8,0,2_000_000)
 c=only(values(s["chunks"]));@test c["food_ref"]==7
 original=deepcopy(c)
 @test mb_food_availability(s,c)==.25
 mb_observe!(s,chunk_view(3_000_000,"far"),3_000_000)
 weak=mb_chunk_candidates!(s,move,"food",90.,0.,3_000_000;H=8)
 @test !isempty(weak) && all(p->p["food_ref"]==7,weak)
 @test mb_daily_evidence(s,move,90.,0.,3_000_000)["mode"]=="unknown_food"
 mb_food_site_observe!(s,7,1,3_000_000,"visible")
 strong=mb_chunk_candidates!(s,move,"food",90.,0.,3_000_000;H=8)
 @test first(strong)["priority"]>first(weak)["priority"]
 @test mb_daily_evidence(s,move,90.,0.,3_000_000)["site_ref"]==7
 @test c==original
 home=copy(c);home["goal"]="home"
 mb_food_site_observe!(s,7,0,4_000_000,"harvest_contact")
 @test mb_food_availability(s,home)==1.
 walk["purpose_family"]="home"
end

