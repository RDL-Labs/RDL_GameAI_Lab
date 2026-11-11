using Test
D(args...)=Dict{String,Any}(args...)
const ANGLES=(-90,-45,0,45,90)
include("../../src/lw/configured_paths/routine_actions.jl")
include("../../src/lw/configured_paths/return_purpose.jl")
@testset "configured routine priority and opt out" begin
 normal=(bypass_scheduled_rest=false,bypass_social_wait=false)
 bypass=(bypass_scheduled_rest=true,bypass_social_wait=true)
 @test configured_routine_priority(true,true,true,true,1,"night",10,5,true,normal)["action"]=="eat"
 @test configured_routine_priority(true,false,true,true,1,"night",10,5,true,normal)["action"]=="retrieve"
 @test configured_routine_priority(false,false,true,true,0,"night",10,5,true,normal)["configured_rule"]=="quiet_night"
 @test configured_routine_priority(false,false,true,false,0,"exploration",10,5,true,normal)["configured_rule"]=="pending_social_reply"
 @test configured_routine_priority(false,false,true,false,0,"night",10,5,true,bypass)===nothing
 @test configured_routine_priority(true,true,true,true,1,"night",10,5,true,normal;enabled=false)===nothing
 @test configured_navigation_priority(false,false,3,"exploration",normal)===nothing
 @test configured_navigation_priority(false,false,9,"exploration",normal)===nothing
 @test configured_navigation_priority(true,false,0,"orientation",normal)===nothing
 @test configured_navigation_priority(false,false,0,"orientation",normal)===nothing
 @test configured_navigation_priority(true,true,3,"exploration",normal)["action"]=="deposit"
 @test configured_navigation_priority(true,true,0,"exploration",normal;enabled=false)===nothing
 @test configured_near_food(false,D("distance"=>1.25,"ref"=>0),D())["action"]=="pickup"
 @test configured_near_food(false,D("distance"=>1.26,"ref"=>0),D())===nothing
 @test configured_near_food(false,D("distance"=>1.,"ref"=>0),D();enabled=false)===nothing
 @test configured_camp_learning_rest(true,true,false,true)["configured_rule"]=="camp_learning_rest"
 @test configured_camp_learning_rest(true,true,true,true)===nothing
 s=return_purpose()
 @test !configured_returning!(s,"exploration",5,false,0)
 @test configured_returning!(s,"exploration",6,false,1)
 @test !configured_returning!(s,"exploration",0,true,2)
 @test s["completed"]==1
end
