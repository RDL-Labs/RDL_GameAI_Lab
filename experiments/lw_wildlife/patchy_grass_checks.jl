include("diverse_start_checks.jl")
include("../../src/lw/configured_paths/rabbit_patchy_grass.jl")
@testset "patchy initial grass preserves capacity and animals" begin
 baseline=deepcopy(replica);other=deepcopy(replica)
 record=configured_rabbit_patchy_grass!(replica);configured_rabbit_patchy_grass!(other)
 @test replica.world.grass==other.world.grass
 @test replica.world.capacity==baseline.world.capacity
 @test replica.world.updated==baseline.world.updated
 @test replica.world.grown==replica.world.eaten==0
 @test replica.world.initial==sum(replica.world.grass)
 @test replica.animals.energy==baseline.animals.energy
 @test replica.animals.x==baseline.animals.x && replica.animals.z==baseline.animals.z
 @test replica.life.rng==baseline.life.rng
 @test all(.2 .* replica.world.capacity .<= replica.world.grass .<= replica.world.capacity)
 @test .2<record.fraction<1
 @test G.snapshot(replica).grass_initial≈sum(replica.world.grass)
 println("INITIAL_GRASS ",JSON3.write(record))
end
