using JSON3,Test,Serialization
include("predator_generations.jl")
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
s=G.build(input.scene,input.clock);w=s.world;a=s.animals
H.enable_grass_layers!(w)
@testset "two layer world and simultaneous intake" begin
 @test sum(w.layers.short)+sum(w.layers.long)≈w.initial
 k=findfirst(>(0),w.capacity)
 w.grass[k]=w.capacity[k]*.25;w.layers.short[k]=w.grass[k]*.6;w.layers.long[k]=w.grass[k]*.4
 reference=deepcopy(w)
 H.grass!(w,k,5*17280)
 for t in 1:500;H.grass!(reference,k,t*172);end
 H.grass!(reference,k,5*17280)
 @test w.grass[k]≈reference.grass[k]
 @test w.layers.short[k]≈reference.layers.short[k]
 @test w.layers.long[k]≈reference.layers.long[k]
 @test w.layers.short[k]+w.layers.long[k]≈w.grass[k]
 @test w.grass[k]<=w.capacity[k]
 # Fresh world for exact food accounting and actual mixed short/long competition.
 s2=G.build(input.scene,input.clock);w2=s2.world;a2=s2.animals;H.enable_grass_layers!(w2)
 k=H.cell(w2,a2.x[1],a2.z[1]);w2.layers.short[k]=.01;w2.layers.long[k]=2.;w2.grass[k]=2.01;w2.initial=sum(w2.grass)
 for i in 1:3
  a2.x[i],a2.z[i]=H.center(w2,k);a2.energy[i]=i==1 ? 70. : 30.;a2.sleepy[i]=0.;a2.gut[i]=0.;a2.state[i]=H.GRAZE
 end
 alive=falses(length(a2.x));alive[1:3].=true
 H.step!(w2,a2,0,zeros(length(w2.grass)),zeros(length(w2.grass)),zeros(length(a2.x)),Int[];alive)
 @test a2.consumed[1]≈.01
 @test a2.consumed[2]≈.0125
 @test a2.consumed[3]≈.0125
 @test w2.layers.long_eaten≈.025
 @test w2.layers.short_eaten≈.01
 @test w2.initial+w2.grown≈sum(w2.grass)+w2.eaten
 @test w2.eaten≈sum(a2.consumed)
 @test H.grass_layer_snapshot(w2).short_eaten≈.01
 # Long vegetation provides greater cover at equal biomass.
 w2.layers.short[k]=1.;w2.layers.long[k]=0.;w2.grass[k]=1.
 short_cover=H.grass_cover!(w2,k,0)
 w2.layers.short[k]=0.;w2.layers.long[k]=1.
 @test H.grass_cover!(w2,k,0)>short_cover
 o=H.observe_grass!(w2,k,0)
 @test H.configured_rabbit_layer_observation(o,70.).food==0.
 @test H.configured_rabbit_layer_observation(o,30.).food==1.
 io=IOBuffer();serialize(io,w);seekstart(io);copy_world=deserialize(io)
 @test copy_world.layers.short==w.layers.short
end
