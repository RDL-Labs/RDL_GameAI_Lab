using Test,Serialization
include(joinpath(@__DIR__,"../../src/lw/configured_paths/rabbit_food_pressure_experiment.jl"))
@testset "Food goal survives local movement" begin
 body=(energy=[5.],gut=[0.]);parent=RabbitFoodPressure()
 for t in 1:2000
  configured_food_search_update!(parent,body,1,t;search_tick=true)
  configured_food_pressure!(parent,body,1,t)
 end
 @test parent.H>4
 @test configured_food_search_radius(parent.H)>1
 @test configured_food_search_radius(0.)==1
 @test configured_food_search_radius(100.)==RABBIT_FOOD_SEARCH.maximum_radius
 prior=parent.H
 configured_food_search_update!(parent,body,1,2001;intake=true)
 @test configured_food_search_state(parent).active
 @test parent.H==prior
 io=IOBuffer();serialize(io,parent);seekstart(io);restored=deserialize(io)
 @test configured_food_search_state(restored).search_ticks==2000
 body.gut[1]=1.
 configured_food_search_update!(restored,body,1,2002;intake=true)
 @test !configured_food_search_state(restored).active
 @test restored.H==0.
 @test parent.H==prior
 @test length(parent.records)<=64
end
