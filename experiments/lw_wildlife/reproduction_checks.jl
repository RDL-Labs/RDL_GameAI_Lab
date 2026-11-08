using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
const G=LW.LWGrazing
const R=G.RABBIT_LIFE
const input=JSON3.read(read(joinpath(@__DIR__,"../rock_gate/channel_trial_spec.json"),String))
function reproductive_world(;enabled=true)
 scene=merge((;pairs(input.scene)...),(wildlife=(enabled=true,count=2,seed=42,reproduction=enabled),))
 s=G.build(scene,input.clock);empty!(s.world.obstacles)
 for i in 1:2
  s.animals.x[i]=-10.;s.animals.z[i]=6.;s.animals.current_cell[i]=G.H.cell(s.world,-10.,6.)
 end
 s.life!==nothing && (s.life.sex.=[1,2])
 s
end
function timed_birth!(s)
 s.life.due[1]=R.day_ticks;s.life.litter[1]=3;s.life.conceptions=1
 s.life.invested[1]=30.;s.life.gestation_out=30.
 # Physiology boundary fixture only: production keeps a 31-day gestation.
 for t in 0:R.day_ticks-1
  G.prepare!(s,[(100.,100.),(101.,100.),(102.,100.)],t);G.advance!(s,t)
 end
end
@testset "birth allocation, state time, nursing and no fabricated grass" begin
 s=reproductive_world();timed_birth!(s)
 @test length(s.alive)==5
 @test s.life.births==3 && s.life.litters==1
 @test all(s.life.mother[3:5].==1)
 @test all(s.life.born[3:5].==R.day_ticks)
 @test all(s.animals.counts[3:5,:].==0)
 @test s.life.gestation_out≈s.life.newborn_energy+sum(s.life.invested)+s.life.lost_investment
 @test G.snapshot(s).reproduction.dependent==3
 @test length(LW.wildlife_motion_objects(s,[(0.,0.),(0.,0.)]))==5
 @test LW.wildlife_motion_objects(s,[(0.,0.),(0.,0.)])[3].vx==0.
 infant_positions=collect(zip(s.animals.x[3:5],s.animals.z[3:5]))
 for t in R.day_ticks:3R.day_ticks-1
  G.prepare!(s,[(100.,100.),(101.,100.),(102.,100.)],t);G.advance!(s,t)
 end
 @test collect(zip(s.animals.x[3:5],s.animals.z[3:5]))==infant_positions
 @test all(s.animals.consumed[3:5].==0)
 @test s.life.nursing_visits>0
 @test s.life.milk_in≈s.life.milk_out*R.milk_efficiency
 report=G.snapshot(s)
 @test report.grass_initial+report.grass_grown≈report.grass_remaining+report.grass_eaten
 @test report.count==report.alive+report.starvation_deaths
 io=IOBuffer();serialize(io,s);seekstart(io);resumed=deserialize(io)
 for t in s.ticks:s.ticks+200
  for state in (s,resumed);G.prepare!(state,[(100.,100.),(101.,100.),(102.,100.)],t);G.advance!(state,t);end
 end
 @test G.snapshot(s)==G.snapshot(resumed)
 @test !G.dependent(s.life,3,s.life.born[3]+R.wean_days*R.day_ticks)
end
@testset "reproduction boundaries and observation" begin
 s=reproductive_world()
 s.animals.energy.=R.breeding_energy-1
 G.rabbit_daily!(s,R.day_ticks)
 @test s.life.conceptions==0
 s.animals.energy.=90.
 G.rabbit_daily!(s,R.season_days*R.day_ticks)
 @test s.life.conceptions==0
 s.life.sex.=[1,1]
 for day in 1:30;G.rabbit_daily!(s,day*R.day_ticks);end
 @test s.life.conceptions==0
 s.life.sex.=[1,2];s.life.born.=0
 G.rabbit_daily!(s,R.day_ticks)
 @test s.life.conceptions==0
 s=reproductive_world();s.life.due[1]=R.day_ticks;s.life.litter[1]=3;s.life.invested[1]=5.
 s.alive[1]=false;s.deaths=1;G.rabbit_daily!(s,R.day_ticks)
 @test s.life.births==0 && s.life.lost_pregnancies==1 && s.life.lost_investment==5.
 s=reproductive_world(enabled=false)
 @test s.life===nothing
 @test G.rabbit_visibility(s,1)==1.
 objects=[(x=0.,z=3.,vx=.1,vz=0.,visibility=.25)]
 @test LW.task_motion_notice((0.,0.),0.,objects)===nothing
 @test isempty(LW.wildlife_view((0.,0.),0.,objects))
end

@testset "initial pregnant cohort" begin
 life=G.rabbit_life(30,20261028,fill((0.,0.),30);initial_pregnancy_days=[26,21,16,11,6])
 @test sort(filter(>(0),life.due))==[5,10,15,20,25].*R.day_ticks
 @test count(>(0),life.due)==5
 @test all(i->life.due[i]==0 || life.sex[i]==1,1:30)
 @test life.gestation_out==sum(life.invested)==80.
 @test life.conceptions==5
 @test_throws ErrorException G.rabbit_life(2,42,fill((0.,0.),2);initial_pregnancy_days=[31])
 @test_throws ErrorException G.rabbit_life(2,42,fill((0.,0.),2);initial_pregnancy_days=[2,3])
end

@testset "initial mother and young" begin
 cfg=(enabled=true,count=30,seed=20261028,reproduction=true,
      initial_pregnancy_days=[26,21,16,11,6],initial_young_count=5,initial_young_age_days=7)
 scene=merge((;pairs(input.scene)...),(wildlife=cfg,))
 s=G.build(scene,input.clock)
 @test length(s.alive)==35
 @test s.life.initial_count==35 && s.life.births==0 && s.life.litters==0
 @test G.snapshot(s).reproduction.initial_young==5
 mother=only(unique(s.life.mother[31:35]))
 @test s.life.due[mother]==0 && s.life.sex[mother]==1
 @test all(s.life.born[31:35].==-7R.day_ticks)
 @test all(s.animals.energy[31:35].==R.milk_target)
 @test s.life.gestation_out==80. && s.life.newborn_energy==0. && s.life.milk_in==0.
 @test G.dependent(s.life,31,21R.day_ticks-1)
 @test !G.dependent(s.life,31,21R.day_ticks)
 humans=[(1000.,1000.) for _ in scene.positions]
 for t in 0:99;G.prepare!(s,humans,t);G.advance!(s,t);end
 @test all(s.alive[31:35]) && all(.!s.life.moving[31:35])
 @test all(s.animals.counts[31:35,G.H.SLEEP].==100)
 @test G.snapshot(s).reproduction.balances.gestation.status=="ok"
 io=IOBuffer();serialize(io,s);seekstart(io);resumed=deserialize(io)
 for world in (s,resumed);G.prepare!(world,humans,100);G.advance!(world,100);end
 @test G.snapshot(s)==G.snapshot(resumed)
 # A focused boundary check uses a clone; no skipped-time result is reported.
 boundary=deepcopy(s);boundary.ticks=21R.day_ticks
 G.prepare!(boundary,humans,boundary.ticks)
 @test all(boundary.life.moving[31:35])
 @test_throws ErrorException G.build(merge(scene,(wildlife=merge(cfg,(reproduction=false,initial_pregnancy_days=Int[],)),)),input.clock)
 @test_throws ErrorException G.build(merge(scene,(wildlife=merge(cfg,(initial_young_age_days=28,)),)),input.clock)
end

@testset "nursing potential avoids a local rock without teleporting" begin
 s=reproductive_world();s.life.litter[1]=3;s.life.invested[1]=24.;s.life.gestation_out=24.
 s.animals.x[1]=-6.;G.rabbit_birth!(s,1,0)
 s.animals.x[1]=-10.;s.animals.current_cell[1]=G.H.cell(s.world,-10.,6.)
 s.life.nursed_day[3:5].=-1
 s.animals.energy[3:5].=4. # Hunger, not calendar alone, requests nursing.
 push!(s.world.obstacles,G.H.RDLMigrationProbe.Circle(-8.,6.,.4))
 initial=deepcopy(s);humans=[(1000.,1000.) for _ in s.previous_humans]
 for t in 0:99
  previous=(s.animals.x[1],s.animals.z[1])
  G.prepare!(s,humans,t);G.advance!(s,t)
  @test hypot(s.animals.x[1]-previous[1],s.animals.z[1]-previous[2])<=.2+1e-10
  @test G.H.clear(s.world,previous,(s.animals.x[1],s.animals.z[1]))
  all(s.life.nursed_day[3:5].==0) && break
 end
 @test all(s.life.nursed_day[3:5].==0)
 @test s.animals.blocked[1]==0
 @test s.life.nest_return_ticks>0
 # OFF retains the old straight return, for regression diagnosis.
 for t in 0:99;G.prepare!(initial,humans,t);G.advance!(initial,t;nursing_potential=false);end
 @test initial.animals.blocked[1]>0
 @test all(initial.life.nursed_day[3:5].==-1)
end
