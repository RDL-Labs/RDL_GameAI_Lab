using Test
include("../../src/lw/LW.jl")
@testset "contextual interruption shielding" begin
 motion=LW.D("distance"=>6.)
 @test LW.configured_task_interrupt(motion,0.,0.).wake
 @test !LW.configured_task_interrupt(motion,4.,0.).wake
 @test !LW.configured_task_interrupt(motion,0.,.9).wake
 @test LW.configured_task_interrupt(motion,4.,.9;enabled=false).wake
 @test LW.configured_task_interrupt(LW.D("distance"=>2.),100.,1.).wake
 gate=LW.configured_task_interrupt(motion,4.,.9)
 @test LW.configured_task_interrupt(LW.D("distance"=>gate.radius),4.,.9).wake
 @test LW.configured_task_interrupt(LW.D(),4.,.9).wake
 # An early weak object must not mask a later nearby object.
 objects=[(x=0.,z=z,vx=0.,vz=.1) for z in (7.,1.)]
 @test LW.task_motion_notice((0.,0.),0.,objects)["distance"]==1.
 @test LW.task_motion_notice((0.,0.),0.,reverse(objects))["distance"]==1.
 s=LW.task_focus_state();b=LW.Body(10.,0.,90.,0.)
 LW.task_focus_record!(s,LW.D("action"=>"fish"),"fishing",b,(0.,0.),0.,"exploration",0,0,nothing)
 @test LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",1_000_000,motion;need=4.)
 @test s["suppressed_motion"]==1
 @test !s["last_interrupt"]["wake"]
 @test !LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",64_000_000,motion;need=4.)
 @test s["wakeups"]["review"]==1
 LW.task_focus_record!(s,LW.D("action"=>"fish"),"fishing",b,(0.,0.),0.,"exploration",0,0,nothing)
 @test !LW.task_focus_continue!(s,LW.Body(10.,0.,0.,0.),(0.,0.),0.,"exploration",1,motion;need=4.)
 @test s["wakeups"]["body"]==1
end
@testset "shared task focus lifecycle" begin
 for (action,status) in (("fish","fishing"),("process_food","processing"))
  s=LW.task_focus_state();b=LW.Body(10.,0.,90.,0.);p=LW.D("action"=>action)
  LW.task_focus_record!(s,p,status,b,(0.,0.),0.,"exploration",0,0,nothing)
  @test LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",1_000_000,nothing)
  @test !LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",2_000_000,LW.D("kind"=>"motion"))
  LW.task_focus_record!(s,p,status,b,(0.,0.),0.,"exploration",0,0,nothing)
  @test !LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",64_000_000,nothing)
  LW.task_focus_record!(s,p,status,b,(0.,0.),0.,"exploration",0,0,nothing)
  LW.task_focus_record!(s,p,"processed",b,(0.,0.),0.,"exploration",1,0,nothing)
  @test !s["active"]
 end
end
@testset "processing completes while observations are suppressed" begin
 a=first(LW.IDS);w=LW.world(true)
 for id in LW.IDS;w.inventory[id]=0;end
 w.bodies[a]=LW.Body(10.,0.,95.,0.)
 stores=Dict(id=>0 for id in LW.IDS);food=[(x=0.,z=1.,stock=0,food_kind=5,renewable=false)]
 stock=[0];r=LW.food_resources((typed_food=true,),w,food,stock,0,stores)
 LW.food_push!(r,a,5);w.inventory[a]=1;r.initial[5]+=1
 @test LW.configured_task_progress(r,a,"process_food")==0.
 r.progress[a]=(UInt8(LW.RDLBody.SALTED_FISH),60)
 @test LW.configured_task_progress(r,a,"process_food")==.5
 r.progress[a]=(UInt8(0),0)
 fs=LW.fishing_state!(r,a);fs["active"]=LW.D("ticks"=>90)
 @test LW.configured_task_progress(r,a,"fish")==.5
 fs["active"]=nothing
 s=LW.task_focus_state();plan=LW.D("action"=>"process_food","food_kind"=>5);observations=0
 for t in 0:119
  focused=LW.task_focus_continue!(s,w.bodies[a],(0.,0.),0.,"exploration",t*1_000_000,nothing)
  observations+=!focused
  w.bodies[a],status,_,_=LW.step(w.bodies[a],"process_food",1)
  @test status=="worked"
  outcome=LW.food_process!(r,a;kind=5,now=t*1_000_000)
  LW.task_focus_record!(s,plan,outcome,w.bodies[a],(0.,0.),0.,"exploration",t*1_000_000,1,nothing)
 end
 @test observations==2
 @test s["skipped"]==118
 @test !s["active"]
 @test r.inventory[a]==[7]
 @test LW.food_audit!(r,w,stock,0,stores)===nothing
end
@testset "rest shares light attention without motion shielding" begin
 b=LW.Body(10.,.2,90.,0.);p=LW.D("action"=>"rest","target"=>"home")
 s=LW.task_focus_state()
 LW.task_focus_record!(s,p,"performed",b,(0.,0.),0.,"return",0,0,nothing)
 @test LW.task_focus_continue!(s,b,(0.,0.),0.,"return",1_000_000,nothing)
 @test s["plan"]["target"]=="home"
 @test !LW.task_focus_continue!(s,LW.Body(10.,0.,90.,0.),(0.,0.),0.,"return",2_000_000,nothing)
 @test s["wakeups"]["recovered"]==1
 LW.task_focus_record!(s,p,"performed",b,(0.,0.),0.,"return",0,0,nothing)
 @test !LW.task_focus_continue!(s,b,(0.,0.),0.,"return",1_000_000,LW.D("distance"=>7.);need=100.)
 LW.task_focus_record!(s,p,"performed",b,(0.,0.),0.,"return",0,0,nothing)
 @test !LW.task_focus_continue!(s,b,(0.,0.),0.,"return",64_000_000,nothing)
 LW.task_focus_record!(s,p,"performed",b,(0.,0.),0.,"return",0,0,nothing;rest_enabled=false)
 @test !s["active"]
end
