using Test
include("../../src/lw/LW.jl")
@testset "rabbit motion then inspection" begin
 obj=[(actor="",x=0.,z=1.,vx=.1,vz=0.)]
 notice=LW.task_motion_notice((0.,0.),0.,obj)
 @test notice!==nothing
 @test !haskey(notice,"appearance")
 @test !haskey(notice,"danger")
 s=LW.task_focus_state();b=LW.Body(10.,.2,90.,0.)
 LW.task_focus_record!(s,LW.D("action"=>"fish"),"fishing",b,(0.,0.),0.,"exploration",0,0,nothing)
 @test !LW.task_focus_continue!(s,b,(0.,0.),0.,"exploration",1_000_000,notice;need=4.,progress=.9)
 view=LW.wildlife_view((0.,0.),0.,obj)
 @test length(view)==1
 @test view[1]["appearance"]=="small_furred_long_eared_body"
 @test view[1]["moving"]
 @test !haskey(view[1],"danger") && !haskey(view[1],"safe")
 stationary=[(actor="",x=0.,z=1.,vx=0.,vz=0.)]
 @test LW.task_motion_notice((0.,0.),0.,stationary)===nothing
 @test length(LW.wildlife_view((0.,0.),0.,stationary))==1
 @test isempty(LW.wildlife_view((0.,0.),180.,obj))
 @test isempty(LW.wildlife_view((0.,0.),0.,[(actor="",x=0.,z=20.,vx=.1,vz=0.)]))
 @test LW.wildlife_motion_objects(nothing,[])==[]
 world=(animals=(x=[1.,2.],z=[3.,4.]),alive=[true,false])
 adapted=LW.wildlife_motion_objects(world,[(0.,3.),(2.,4.)])
 @test length(adapted)==1 && adapted[1].vx==1.
end
