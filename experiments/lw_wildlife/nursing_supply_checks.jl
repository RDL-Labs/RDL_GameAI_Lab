include("burrow_checks.jl")
@testset "batch supply and partial nursing retry" begin
 s=reproductive_world();G.rabbit_initial_young!(s,3,1);a=s.animals
 a.energy[3:5].=2.;a.energy[1]=35.02
 G.rabbit_nurse!(s,0)
 @test all(s.life.nursed_day[3:5].==0)
 @test all(a.energy[3:5].<4)
 before=s.life.milk_in;a.energy[1]=85.
 G.rabbit_nurse!(s,1)
 @test all(a.energy[3:5].≈8.)
 @test s.life.milk_in>before
 milk=s.life.milk_in;G.rabbit_nurse!(s,2)
 @test s.life.milk_in==milk
 a.energy[3:5].=3.;a.x[1]-=5.;a.energy[1]=36.;a.gut[1]=0.;a.sleepy[1]=0.
 forecast=G.configured_rabbit_nursing_forecast(s,1,[3,4,5])
 @test 55<forecast.departure_energy<=85
 G.configured_rabbit_nursing!(s,3)
 @test s.life.nest_return_ticks==0
 @test s.overrides[1]==G.H.GRAZE
 a.energy[1]=85.;fill!(s.overrides,0);G.configured_rabbit_nursing!(s,4)
 @test s.life.nest_return_ticks==1
 @test s.overrides[1]==G.H.SEARCH
 @test a.target[1]==G.H.cell(s.world,s.life.nest[3]...)
 fill!(s.overrides,0);s.overrides[1]=G.H.FLEE;G.configured_rabbit_nursing!(s,5)
 @test s.overrides[1]==G.H.FLEE
end
