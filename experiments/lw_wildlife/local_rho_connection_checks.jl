using JSON3,Test,Serialization
include("predator_generations.jl")
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
s=G.build(input.scene,input.clock);w=s.world;a=s.animals;H.enable_grass_layers!(w)
a.x[1]=15.062265075839024;a.z[1]=31.04703384413854
a.current_cell[1]=H.cell(w,a.x[1],a.z[1]);a.target[1]=0;a.energy[1]=60.;a.sleepy[1]=0.
policy=H.RabbitSwimmingPolicy();alive=falses(length(a.x));alive[1]=true
@testset "normal local rho connection" begin
 @test H.clear(w,(a.x[1],a.z[1]),(a.x[1],a.z[1]))
 for t in 0:499
  H.step!(w,a,t,s.demand,s.ratio,s.requests,s.active;alive,policy)
 end
 stats=H.rabbit_rho_snapshot(policy)
 @test stats.queries>0
 @test get(stats.events,"fine_choice",0)>0
 @test a.consumed[1]>0
 @test w.eaten≈sum(a.consumed)
 @test w.initial+w.grown≈sum(w.grass)+w.eaten
 @test H.clear(w,(a.x[1],a.z[1]),(a.x[1],a.z[1]))
 io=IOBuffer();serialize(io,policy);seekstart(io)
 @test H.rabbit_rho_snapshot(deserialize(io))==stats
 r=H.approach_memory(policy.base,1).local_rho
 for t in 1:100;H.rho_record!(r,(event="test",tick=t));end
 @test length(r.records)<=H.RABBIT_LOCAL_RHO.history_limit
 @test r.counts["test"]==100
end
