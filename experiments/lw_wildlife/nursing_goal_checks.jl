using Test
include("predator_generations.jl")
@testset "nursing outcome" begin
 life=G.rabbit_life(2,1,[(0.,0.),(0.,0.)]);life.mother[2]=1;life.born[2]=0
 a=(x=[0.,1.],z=[0.,0.],energy=[35.1,3.])
 s=(life=life,animals=a,alive=trues(2),overrides=zeros(UInt8,2))
 push!(life.nursing_pending,2)
 G.rabbit_nurse!(s,1)
 @test a.energy[2]>3.
 @test 2 in life.nursing_pending
 a.energy[1]=85.;a.energy[2]=5.
 G.rabbit_nurse!(s,2)
 @test a.energy[2]≈8.
 @test !(2 in life.nursing_pending)
 a.energy[2]=3.;push!(life.nursing_pending,2);s.overrides[1]=H.FLEE
 G.rabbit_nurse!(s,3)
 @test a.energy[2]==3.
 @test 2 in life.nursing_pending
 s.overrides[1]=0;a.x[2]=2.
 @test G.configured_rabbit_nursing_forecast(s,1,[2]).goal==(2.,0.)
 G.rabbit_nurse!(s,4)
 @test 2 in life.nursing_pending
end
