include("reproduction_checks.jl")
@testset "body reserve and recent balance" begin
 p=G.rabbit_conception_probability
 @test p(35.,10.)==0
 @test p(85.,0.)≈.2
 @test 0<p(60.,0.)<p(70.,0.)<p(85.,0.)
 @test p(70.,-10.)<p(70.,0.)<p(70.,10.)<=.2
 @test p(69.,0.;enabled=false)==0
 @test p(70.,-10.;enabled=false)==.2
 s=reproductive_world();s.animals.energy[1]=60.
 G.rabbit_reserve_sample!(s,R.day_ticks)
 @test s.life.reserve_balance[1]<0
 saved_balance=s.life.reserve_balance[1]
 G.rabbit_reserve_sample!(s,R.day_ticks)
 @test s.life.reserve_balance[1]==saved_balance
 s.animals.energy[1]=70.;G.rabbit_reserve_sample!(s,2R.day_ticks)
 @test s.life.reserve_balance[1]>saved_balance
 io=IOBuffer();serialize(io,s);seekstart(io);resumed=deserialize(io)
 @test resumed.life.reserve_balance==s.life.reserve_balance
 @test resumed.life.reserve_sample_tick==s.life.reserve_sample_tick
 s.life.litter[1]=3;s.life.invested[1]=24.;G.rabbit_birth!(s,1,2R.day_ticks)
 @test length(s.life.reserve_balance)==length(s.alive)
 @test all(s.life.reserve_balance[end-2:end].==0)
 @test all(s.life.reserve_sample_tick[end-2:end].==2R.day_ticks)
end
@testset "condition reaches daily conception decision" begin
 low=0;high=0
 for trial in 1:100
  s=reproductive_world();G.Random.seed!(s.life.rng,trial);s.life.receptive_phase.=0
  s.animals.energy[1]=70.;s.life.reserve_previous[1]=70.;s.life.reserve_sample_tick[1]=R.day_ticks
  scarce=deepcopy(s);scarce.life.reserve_balance[1]=-10.
  G.rabbit_daily!(s,R.day_ticks);G.rabbit_daily!(scarce,R.day_ticks)
  high+=s.life.conceptions;low+=scarce.life.conceptions
  @test scarce.life.conceptions<=s.life.conceptions
 end
 @test high>low
end
