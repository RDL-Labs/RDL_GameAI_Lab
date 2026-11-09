using Test
include("predator_generations.jl")
@testset "burrow refuge" begin
 life=G.rabbit_life(2,1,[(0.,0.),(0.,0.)]);life.mother[2]=1;life.born[2]=0
 a=(x=[0.,0.],z=[0.,0.]);s=(life=life,animals=a,overrides=UInt8[0,H.FLEE])
 t=20*17280
 @test G.configured_rabbit_in_burrow(s,2,t)
 G.configured_rabbit_refuge_response!(s,2,t)
 @test s.overrides[2]==H.REST
 a.x[2]=1.;s.overrides[2]=H.ALERT
 G.configured_rabbit_refuge_response!(s,2,t)
 @test s.overrides[2]==H.FLEE
 @test G.configured_rabbit_refuge_goal(s,2,t)==(0.,0.)
 a.x[2]=2.1
 @test G.configured_rabbit_refuge_goal(s,2,t)===nothing
 @test G.configured_rabbit_refuge_goal(s,1,t)===nothing
 a.x[2]=0.;s.overrides[2]=0
 G.configured_rabbit_refuge_response!(s,2,t)
 @test s.overrides[2]==0
 @test G.configured_rabbit_refuge_goal(s,2,28*17280)===nothing
end
