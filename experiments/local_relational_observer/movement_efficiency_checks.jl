using Test
include("../../src/lw/LW.jl")
const D=LW.D
function movement_trial(actions,energy;resolved=true)
    map=LW.mb_map_state("test")
    plan=D("action"=>"walk")
    LW.mb_parent_begin!(map,plan,"home",nothing,0)
    active=map["parent_mb"]["active"]["home"]
    estimate=active["estimate"]
    estimate["expected_actions"]=100.;estimate["upper_actions"]=150.
    estimate["expected_energy"]=10.;estimate["energy"]=15.
    active["actions"]=actions;active["energy"]=energy
    LW.mb_parent_record!(map,plan,0.,0)
    # Restore controlled costs after recording the source binding.
    active["actions"]=actions;active["energy"]=energy
    LW.mb_parent_H_increment!(map,"home","op:0:test",resolved,1_000_000)
    reward=LW.mb_parent_efficiency_reward(map,"home","op:0:test",1_000_000)
    loop=LW.BasicLoop("test:home")
    LW.choose_method!(loop,[D("method"=>"route","priority"=>0.,"question"=>"movement_progress")],1)
    LW.loop_forecast_difference!(loop,nothing,8.,0.)
    LW.resolve_method!(loop,1,true,resolved;method_forecast=(0.,1.),
        goal_forecast=(0.,0.),completion_reward=reward,goal_release=resolved ? 8. : nothing)
    (;map,loop,reward)
end
@testset "arrival-conditioned movement efficiency" begin
    road=movement_trial(50,5.)
    expected=movement_trial(100,10.)
    costly=movement_trial(150,15.)
    unfinished=movement_trial(1,.1;resolved=false)
    @test road.reward>0
    @test expected.reward==0
    @test costly.reward==0
    @test unfinished.reward===nothing
    @test unfinished.loop.methods["route"].reward==0
    @test unfinished.loop.H==8
    @test road.loop.H==expected.loop.H==costly.loop.H==0
    @test road.loop.methods["route"].reward==road.reward
    @test expected.loop.methods["route"].reward==costly.loop.methods["route"].reward==0
    @test LW.mb_parent_efficiency_reward(road.map,"food","op:0:test",1_000_000)===nothing
    @test LW.mb_parent_efficiency_reward(road.map,"home","wrong",1_000_000)===nothing
    @test LW.mb_parent_efficiency_reward(road.map,"home","op:0:test",2_000_000)===nothing
    println("efficiency reward: road=",road.reward," expected=",expected.reward," costly=",costly.reward," unfinished=",unfinished.reward)
end
@testset "repeated successful steps do not pay" begin
    loop=LW.BasicLoop("test:food")
    for source in 1:100
        LW.choose_method!(loop,[D("method"=>"walk","priority"=>0.,"question"=>"movement_progress")],source)
        LW.resolve_method!(loop,source,true,false;method_forecast=(0.,1.),goal_forecast=(0.,0.))
    end
    @test loop.methods["walk"].reward==0
    @test all(e.method_reward==0 for e in loop.events)
end
