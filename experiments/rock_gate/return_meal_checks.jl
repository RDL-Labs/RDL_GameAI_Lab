using Test
include("../../src/lw/LW.jl")
const D=LW.D
@testset "return meal before cognition pause" begin
 day=17_280_000_000
 s=D("configured_post_return_idle"=>LW.configured_post_return_idle_state(),"daily_plan"=>D("active"=>D("closed"=>true,"deadline_us"=>day),"records"=>[D("returned"=>true,"food_success"=>true)]))
 raw=(inventory=Dict("npc_a"=>UInt8[3]),)
 @test !LW.configured_post_return_idle!(s,100,day,day-100;require_meal=true)
 @test LW.configured_return_meal_plan(s,raw,"npc_a",100,day,true,true,0)["action"]=="process_food"
 LW.configured_return_meal_record!(s,"process_food","processed",true,101,day)
 @test !LW.configured_post_return_idle!(s,102,day,day-100;require_meal=true)
 @test LW.configured_return_meal_plan(s,(inventory=Dict("npc_a"=>UInt8[4]),),"npc_a",102,day,true,false,0)["action"]=="rest"
 LW.configured_return_meal_record!(s,"eat","gut_full",true,103,day)
 @test !LW.configured_post_return_idle!(s,104,day,day-100;require_meal=true)
 LW.configured_return_meal_record!(s,"eat","ate",false,105,day)
 @test !LW.configured_post_return_idle!(s,106,day,day-100;require_meal=true)
 LW.configured_return_meal_record!(s,"eat","ate",true,107,day)
 @test LW.configured_post_return_idle!(s,108,day,day-100;require_meal=true)
 @test !LW.configured_post_return_idle!(s,109,day,day-100;require_meal=true,pending=true)
 @test !LW.configured_post_return_idle!(s,day-50,day,day-100;require_meal=true)
 @test !LW.configured_post_return_idle!(s,day+1,day,day-100;require_meal=true)
 q=LW.configured_acorn_quest_state();q["stage"]="completed";q["completed_us"]=day+100
 @test !LW.configured_acorn_quest_released(q,2day-1,day)
 @test LW.configured_acorn_quest_released(q,2day,day)
 s["configured_post_return_idle"]=LW.configured_post_return_idle_state()
 s["daily_plan"]["active"]["closed"]=false
 empty!(s["daily_plan"]["records"])
 s["daily_plan"]["local_returns"]=[D("us"=>day+100,"returned"=>true,"food_success"=>false)]
 @test LW.configured_return_meal_due(s,day+101,day)
 @test !LW.configured_post_return_idle!(s,day+101,day,day-100;require_meal=true)
 LW.configured_return_meal_record!(s,"eat","ate",true,day+102,day)
 @test LW.configured_post_return_idle!(s,day+103,day,day-100;require_meal=true)
 @test !s["daily_plan"]["active"]["closed"]
 @test !last(s["daily_plan"]["local_returns"])["food_success"]
 @test LW.configured_return_meal_hold(s,2day-1,day)
 @test !LW.configured_return_meal_hold(s,2day,day)
 @test !LW.configured_return_meal_due(s,2day+1,day)
end
