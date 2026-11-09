using Test
include("../../src/lw/configured_paths/rabbit_food_pressure_experiment.jl")
@testset "food acquired release" begin
 p=RabbitFoodPressure();g=RabbitFoodPressureGate();a=(energy=[85.],gut=[0.])
 configured_food_pressure!(p,a,1,0)
 @test configured_food_pressure_gate!(g,19.,1)==0.
 @test configured_food_pressure_gate!(g,20.,2)==20.
 @test configured_food_pressure_gate!(g,0.,3)>0.
 @test g.active
 configured_food_intake_cooling!(p,g,a,1,4,0.,30.)
 @test g.active
 a.energy[1]=1.;configured_food_pressure!(p,a,1,5);before=p.H
 a.gut[1]=.025
 configured_food_intake_cooling!(p,g,a,1,6,.025,30.)
 @test !g.active
 @test p.H≈before-.025*3/4
 @test p.H>0
 @test g.records[end].event=="food_acquired"
 @test g.calls==3
 # A new search can reactivate; feeding itself never calls the selection gate.
 @test configured_food_pressure_gate!(g,30.,7)==30.
 @test g.active
end
