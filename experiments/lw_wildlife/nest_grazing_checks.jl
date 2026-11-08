include("reproduction_checks.jl")
@testset "maternal nest grazing cost" begin
 for policy in (G.H.StateMachinePolicy(),G.H.RabbitApproachPolicy())
  s=reproductive_world();G.rabbit_initial_young!(s,1,1)
  a=s.animals;k=G.H.cell(s.world,a.x[1],a.z[1])
  a.energy[1:2].=40.;a.gut[1:2].=0.;a.sleepy[1:2].=0.;a.state[1:2].=G.H.REST
  s.world.grass[k]=s.world.capacity[k]
  cost=G.configured_rabbit_nest_grazing(s,0)
  @test cost(1,k)>s.world.grass[k]
  @test cost(2,k)==0
  @test G.configured_rabbit_nest_grazing(s,0;enabled=false)===nothing
  control=deepcopy(s)
  G.prepare!(s,[(100.,100.),(101.,100.),(102.,100.)],0);G.advance!(s,0;grazing_policy=policy)
  G.prepare!(control,[(100.,100.),(101.,100.),(102.,100.)],0);G.advance!(control,0;nest_grazing_avoidance=false)
  @test a.consumed[1]==0
  @test control.animals.consumed[1]>0
  @test a.consumed[2]>0
  @test a.distance[1]>0
  @test a.consumed[3]==0
  @test G.configured_rabbit_nest_grazing(s,28R.day_ticks)===nothing
  s.alive[3]=false
  @test G.configured_rabbit_nest_grazing(s,1)===nothing
 end
end
