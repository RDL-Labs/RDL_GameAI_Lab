using Test
include("../../src/lw/LW.jl")
@testset "continuous hunger and frozen relief forecast" begin
 @test LW.hunger_pressure(81.)==LW.hunger_pressure(80.)==0.
 @test 0<LW.hunger_pressure(79.9)<LW.hunger_pressure(70.)<LW.hunger_pressure(60.)
 h=LW.hunger_state("a")
 LW.hunger_update!(h,"a",0,70.;continuous=true)
 @test h["intensity"]==.25
 LW.hunger_update!(h,"a",60_000_000,70.;continuous=true)
 @test h["H"]==0
 LW.hunger_expect!(h,"home",60_000_000,70.,100.,2.)
 LW.hunger_update!(h,"a",110_000_000,69.;continuous=true)
 @test h["H"]==0
 LW.hunger_expect!(h,"home",110_000_000,69.,100.,2.)
 @test h["forecast"]["started_us"]==60_000_000
 LW.hunger_update!(h,"a",210_000_000,68.;continuous=true)
 @test h["H"]==.5
 LW.hunger_home_observe!(h,0,210_000_000)
 @test h["H"]==1
 @test LW.hunger_relief_score(h,70.,10.,0.,1.)>LW.hunger_relief_score(h,70.,100.,2.,1.)
 @test LW.hunger_relief_score(h,70.,10.,0.,1.)>LW.hunger_relief_score(h,70.,10.,0.,0.)
 LW.hunger_update!(h,"a",220_000_000,81.;continuous=true)
 @test h["H"]==0 && h["forecast"]===nothing
end
@testset "completed delivery is not reopened by hunger" begin
 s=LW.mb_map_state("a");s["daily_plan"]=LW.mb_daily_plan_state("a",9)
 LW.mb_plan_context!(s,0,600_000_000,70.,0.)
 move=LW.D("visible"=>[LW.D("ref"=>0,"distance"=>1.)])
 LW.mb_daily_request!(s,move,nothing,false,0,70.,0.,0,600_000_000)
 a=s["daily_plan"]["active"];a["closed"]=true
 h=LW.hunger_state("a");LW.hunger_update!(h,"a",1,70.;continuous=true)
 LW.hunger_home_observe!(h,2,1);s["hunger_forecast"]=h
 choice=LW.mb_daily_request!(s,move,LW.D("distance"=>0.),true,0,70.,0.,1,600_000_000;replenishing=true)
 @test a["closed"]
 @test haskey(h,"closed_choice")
 @test 0<last(s["daily_plan"]["decisions"])["return_probability"]<1
 @test LW.mb_daily_request!(s,move,LW.D("distance"=>0.),true,0,70.,0.,2,600_000_000)==choice
end
