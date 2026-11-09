using JSON3,Test
include("predator_generations.jl")
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
s=G.build(input.scene,input.clock)
@testset "gradual juvenile feeding" begin
 i=1;s.life.mother[i]=0
 s.life.born[i]=-18*17280
 @test !G.configured_rabbit_self_feeding(s,i,0)
 @test G.configured_rabbit_growth(s,i,1).fraction>0
 s.life.born[i]=-23*17280
 @test G.configured_rabbit_growth(s,i,0).fraction==.5
 @test G.configured_rabbit_growth(s,i,0).radius==4
 s.life.born[i]=-28*17280
 @test G.configured_rabbit_growth(s,i,0)===nothing
 s.life.born[i]=-23*17280;s.animals.energy[i]=20.;s.animals.sleepy[i]=0.
 s.life.nest[i]=(s.animals.x[i],s.animals.z[i]);start=s.animals.consumed[i]
 for t in 0:99
  G.prepare!(s,s.previous_humans,t)
  G.advance!(s,t;grazing_policy=H.RabbitApproachPolicy())
 end
 @test s.animals.consumed[i]>start
 @test sum(s.animals.counts[i,:])==100
 @test hypot(s.animals.x[i]-s.life.nest[i][1],s.animals.z[i]-s.life.nest[i][2])<=G.configured_rabbit_growth(s,i,100).radius
 @test s.world.eaten≈sum(s.animals.consumed)
 @test s.world.initial+s.world.grown≈sum(s.world.grass)+s.world.eaten
 @test s.animals.consumed[i]≈s.animals.gut[i]+s.animals.digested[i]
end
