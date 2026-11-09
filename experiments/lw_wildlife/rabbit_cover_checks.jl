using Test
const GRAZE=UInt8(2);const SEARCH=UInt8(1)
include_string(Main,replace(read(joinpath(@__DIR__,"../../src/lw/configured_paths/rabbit_cover_foraging.jl"),String),"enabled=false"=>"enabled=true"))
@testset "cover and hunger compete without overriding urgent states" begin
 observation(energy,cover;grass=.01)=(energy=energy,grass=grass,vegetation=(cover=cover,))
 @test configured_rabbit_cover_state(GRAZE,observation(75.,0.))==SEARCH
 @test configured_rabbit_cover_state(GRAZE,observation(25.,0.))==GRAZE
 @test configured_rabbit_cover_state(GRAZE,observation(75.,1.))==GRAZE
 @test configured_rabbit_cover_state(GRAZE,(energy=75.,grass=.01,vegetation=nothing))==GRAZE
 for state in UInt8[1,3,4,5,6]
  @test configured_rabbit_cover_state(state,observation(75.,0.))==state
 end
 @test configured_rabbit_cover_bonus(observation(75.,1.),75.)>configured_rabbit_cover_bonus(observation(75.,0.),75.)
 @test configured_rabbit_cover_bonus(observation(25.,1.),25.)==0.
end
module DisabledCover
const GRAZE=UInt8(2);const SEARCH=UInt8(1)
include("../../src/lw/configured_paths/rabbit_cover_foraging.jl")
end
@testset "default off preserves legacy decisions" begin
 o=(energy=75.,grass=.01,vegetation=(cover=0.,))
 @test DisabledCover.configured_rabbit_cover_state(GRAZE,o)==GRAZE
 @test DisabledCover.configured_rabbit_cover_bonus(o,75.)==0.
end
