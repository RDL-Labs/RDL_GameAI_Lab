using JSON3,Test
include("predator_generations.jl")
include("../../src/lw/configured_paths/rabbit_grid_refinement.jl")
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
s=G.build(input.scene,input.clock);old=deepcopy(s)
configured_rabbit_refine_grid!(s,1.)
@testset "one metre grid" begin
 @test s.world.nx==2old.world.nx && s.world.nz==2old.world.nz
 @test sum(s.world.capacity)≈sum(old.world.capacity)
 @test sum(s.world.grass)≈sum(old.world.grass)
 @test s.animals.x==old.animals.x && s.animals.z==old.animals.z
 @test s.animals.energy==old.animals.energy
 @test length(H.rabbit_neighbor_offsets(s.world))==24
 @test maximum(abs(o[1])*s.world.cellsize for o in H.rabbit_neighbor_offsets(s.world))==2.
 for k in eachindex(old.world.capacity)
  ox=mod(k-1,old.world.nx);oz=div(k-1,old.world.nx)
  children=[2ox+dx+1+(2oz+dz)*s.world.nx for dx in 0:1 for dz in 0:1]
  @test sum(s.world.capacity[children])≈old.world.capacity[k]
 end
 # Check actual cached visibility for all new offsets against direct CPU.
 s.animals.state.=H.SEARCH;s.animals.target.=0;s.animals.next_sense.=0
 direct=[H.observe_neighbors!(s.world,s.animals,i,0) for i in eachindex(s.alive)]
 H.enable_rabbit_neighbor_batch!(s.world;gpu=true,audit=true,automatic=true)
 H.prepare_rabbit_neighbor_batch!(s.world,s.animals,0,H.StateMachinePolicy(),s.alive,nothing)
 cached=[H.observe_neighbors!(s.world,s.animals,i,0) for i in eachindex(s.alive)]
 @test direct==cached
 @test H.rabbit_neighbor_stats().hits>0
 H.disable_rabbit_neighbor_gpu!()
 H.enable_grass_layers!(s.world)
 for t in 0:99;G.prepare!(s,copy(s.previous_humans),t);G.advance!(s,t);end
 @test G.snapshot(s).balances.grass.status=="ok"
end
