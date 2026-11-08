include("reproduction_checks.jl")
@testset "burrow shelter and ordinary maternal grazing" begin
 s=reproductive_world();G.rabbit_initial_young!(s,1,1);a=s.animals
 @test G.configured_rabbit_in_burrow(s,3,0)
 @test !G.configured_rabbit_in_burrow(s,1,0)
 @test G.rabbit_visibility(s,3)==0
 @test !G.configured_rabbit_in_burrow(s,3,27R.day_ticks)
 s.predator=G.configured_wildlife_predator(s.world,a,(predator_count=1,),42)
 b=s.predator.body;b.x=a.x[3];b.z=a.z[3]
 seen=Int[]
 G.configured_wildlife_predator_plan!(s,0;illumination=1.,local_planner=(s,obs,t)->(append!(seen,[o.id for o in obs]);true))
 @test !(3 in seen)
 @test 1 in seen
 for probabilistic in (false,true)
  b.state=G.P.ATTACK;b.target=3;b.timer=1;b.attacks+=1
  G.configured_wildlife_predator_advance!(s,0;probabilistic_capture=probabilistic)
  @test s.alive[3] && b.captures==0
  @test b.target==0
 end
 b.state=G.P.SEARCH;b.x=a.x[3]-1;b.z=a.z[3];b.target=3;b.expires=28R.day_ticks;b.seen_x=a.x[3];b.seen_z=a.z[3];s.predator.gaze=0.;empty!(seen)
 G.configured_wildlife_predator_plan!(s,27R.day_ticks;illumination=1.,local_planner=(s,obs,t)->(append!(seen,[o.id for o in obs]);true))
 @test 3 in seen
 s=reproductive_world();G.rabbit_initial_young!(s,1,1);a=s.animals
 s.predator=nothing;a.energy[1]=40.;a.gut[1]=0.;a.sleepy[1]=0.;a.state[1]=G.H.REST
 G.prepare!(s,[(100.,100.),(101.,100.),(102.,100.)],0);G.advance!(s,0)
 @test a.consumed[1]>0
 @test a.consumed[3]==0
end
