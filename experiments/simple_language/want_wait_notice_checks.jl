using Test
include("../../src/lw/LW.jl")
@testset "trade living wait misses separate item offer channel" begin
 body=LW.Body(10,0,90,0);position=(0.,0.);yaw=0.;now=0
 focus=LW.task_focus_state()
 LW.task_focus_record!(focus,LW.configured_trade_living_wait(true),"performed",body,position,yaw,"exploration",now,0,position)
 @test focus["active"]
 @test LW.task_wait_notice(focus,Any[],1_000_000)===nothing
 @test LW.task_focus_continue!(focus,body,position,yaw,"exploration",1_000_000,nothing)
 @test LW.task_focus_continue!(focus,body,position,yaw,"exploration",31_000_000,nothing)
 @test !LW.task_focus_continue!(focus,body,position,yaw,"exploration",64_000_000,nothing)
 # Diagnostic counterfactual only: delivered trade notice could wake the same mechanism.
 LW.task_focus_record!(focus,LW.configured_trade_living_wait(true),"performed",body,position,yaw,"exploration",0,0,position)
 @test !LW.task_focus_continue!(focus,body,position,yaw,"exploration",1_000_000,nothing;wait_notice="trade_offer")
end
