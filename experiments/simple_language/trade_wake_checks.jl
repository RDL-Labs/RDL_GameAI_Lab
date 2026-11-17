include("../portable_items/checks.jl")
@testset "addressed trade wakes rest without forced consent" begin
 f=barter_fixture();focus=LW.task_focus_state();body=f.w.bodies[ITEM_A]
 function rest!()
  LW.task_focus_record!(focus,LW.configured_trade_living_wait(true),"performed",body,f.w.positions[ITEM_A],0.,"exploration",0,0,(0.,0.))
 end
 rest!()
 @test LW.task_trade_notice!(focus,f.s,f.w,ITEM_A,0)===nothing
 offer=item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,want_items=[1])
 before=deepcopy(f.s["items"])
 notice=LW.task_trade_notice!(focus,f.s,f.w,ITEM_A,1_000_000)
 @test notice=="trade_offer"
 @test !LW.task_focus_continue!(focus,body,f.w.positions[ITEM_A],0.,"exploration",1_000_000,nothing;wait_notice=notice)
 @test f.s["items"]==before
 @test haskey(f.s["offers"],offer["offer_id"])
 rest!()
 @test LW.task_trade_notice!(focus,f.s,f.w,ITEM_A,30_000_000)===nothing
 @test LW.task_trade_notice!(focus,f.s,f.w,ITEM_C,1_000_000)===nothing
 prior=f.w.positions[ITEM_B];f.w.positions[ITEM_B]=(100.,100.)
 @test LW.task_trade_notice!(focus,f.s,f.w,ITEM_A,1_000_000)===nothing
 f.w.positions[ITEM_B]=prior
 focus["plan"]["action"]="process_food"
 @test LW.task_trade_notice!(focus,f.s,f.w,ITEM_A,1_000_000)===nothing
 focus["plan"]["action"]="rest"
 @test item_act(f,ITEM_A,"item_decline",2_000_000;offer_id=offer["offer_id"])["status"]=="declined"
 focus["active"]=true
 @test LW.task_trade_notice!(focus,f.s,f.w,ITEM_B,3_000_000;pending_offer=offer["offer_id"])=="trade_result"
 @test LW.task_trade_notice!(focus,f.s,f.w,ITEM_B,3_000_000;pending_offer="unrelated")===nothing
 @test item_checks(f)===nothing
end
