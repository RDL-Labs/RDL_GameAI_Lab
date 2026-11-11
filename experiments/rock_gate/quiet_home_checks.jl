using Test
D(args...)=Dict{String,Any}(args...)
include("../../src/lw/configured_paths/routine_actions.jl")
@testset "quiet night stays inside observed home" begin
 o=(bypass_scheduled_rest=false,bypass_social_wait=false)
 f(home,time;enabled=true,pending=false)=configured_routine_priority(false,false,true,home,0,"night",time,100,pending,o;enabled)
 @test f(false,100)===nothing
 @test f(false,101)===nothing
 @test f(true,99)===nothing
 @test f(true,100)["configured_rule"]=="quiet_night"
 @test f(true,101;enabled=false)===nothing
 @test f(false,101;pending=true)["configured_rule"]=="pending_social_reply"
 @test configured_routine_priority(true,true,true,false,0,"night",101,100,false,o)["action"]=="eat"
 @test configured_routine_priority(false,false,true,true,0,"night",101,100,false,(bypass_scheduled_rest=true,bypass_social_wait=false))===nothing
end
