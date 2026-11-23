using Test,Serialization
include("../julia_migration/lw_integrated/native.jl")
include("food_goal_brightness_overlay.jl")
@testset "source goal brightness, not place repulsion" begin
 s=mb_map_state("a";chunks=true)
 food=D("goal"=>"food","food_ref"=>7,"to"=>"food_end")
 home=D("goal"=>"home","food_ref"=>7,"to"=>"home_end")
 s["chunks"]["food"]=food;s["chunks"]["home"]=home
 @test mb_food_availability(s,food)==1.
 mb_food_site_observe!(s,7,0,1,"visible_empty")
 @test local_food_source_H(s,7)==1.
 @test mb_food_availability(s,food)≈.25
 @test mb_food_availability(s,home)==1.
 p=D("priority"=>4.);local_food_wake_project!(s,p,"food","food_end")
 @test p["priority"]≈1.
 for (goal,node) in (("home","food_end"),("food","other_source"))
  p=D("priority"=>4.);local_food_wake_project!(s,p,goal,node);@test p["priority"]==4.
 end
 opts=[D("priority"=>4.,"food_ref"=>7)]
 @test mb_search_resistance_project!(s,opts,"food",D(),1)==[D("priority"=>4.,"food_ref"=>7)]
 # Another source at the same abstract terminal remains a possible goal.
 s["chunks"]["alternative"]=D("goal"=>"food","food_ref"=>8,"to"=>"food_end")
 p=D("priority"=>4.);local_food_wake_project!(s,p,"food","food_end");@test p["priority"]==4.
 mb_food_site_observe!(s,7,1,2,"visible")
 @test mb_food_availability(s,food)==1.
 @test isempty(s["edges"])
 io=IOBuffer();serialize(io,s);seekstart(io);@test mb_food_availability(deserialize(io),food)==1.
end
