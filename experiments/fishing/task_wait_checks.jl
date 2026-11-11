using Test
include("../../src/lw/LW.jl")
@testset "pending reply remains live during attention suspension" begin
 s=LW.task_focus_state();b=LW.Body(10.,0.,90.,0.)
 pending=LW.D("message_id"=>"m1","target"=>"b","deadline"=>5_000_000)
 plan=LW.D("action"=>"rest","configured_rule"=>"pending_social_reply")
 record(now;wait=pending)=LW.task_focus_record!(s,plan,"performed",b,(0.,0.),0.,"exploration",now,0,nothing;pending_wait=wait)
 record(1_000_000)
 @test s["wait"]["deadline"]==5_000_000
 @test LW.task_wait_notice(s,Any[],4_000_000)===nothing
 @test LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",4_000_000,nothing;wait_notice=LW.task_wait_notice(s,Any[],4_000_000))
 @test !LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",5_000_000,nothing;wait_notice=LW.task_wait_notice(s,Any[],5_000_000))
 @test s["wakeups"]["wait_deadline"]==1
 record(4_000_000)
 @test s["wait"]["deadline"]==5_000_000 # Re-entering rest cannot extend the request.
 msg=LW.D("reply_to"=>"m1","sender"=>"b","kind"=>"refuse","time"=>2.)
 @test LW.task_wait_notice(s,[msg],3_000_000)=="wait_reply"
 @test !LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",3_000_000,nothing;wait_notice=LW.task_wait_notice(s,[msg],3_000_000))
 @test s["wakeups"]["wait_reply"]==1
 @test LW.task_wait_notice(s,[merge(msg,LW.D("sender"=>"other"))],3_000_000)===nothing
 @test LW.task_wait_notice(s,[merge(msg,LW.D("reply_to"=>"old"))],3_000_000)===nothing
 @test LW.task_wait_notice(s,[msg],5_000_000)=="wait_deadline" # Expired packet.
 record(6_000_000;wait=nothing)
 @test s["wait"]===nothing
 @test LW.task_wait_notice(s,[msg],6_000_000)===nothing
end
