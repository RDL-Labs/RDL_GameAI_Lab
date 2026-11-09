using Test
include("../../src/ecology/motion-vision-cpu/Herbivores.jl")
const H=Herbivores
@testset "cover preference preserves all state decisions" begin
    for old in UInt8.(1:6), energy in (10.,25.,65.,85.), grass in (0.,.004,.01,1.), threat in (false,true)
        o=(old=old,energy=energy,gut=0.,sleepy=.3,grass=grass,threat=threat,vegetation=(cover=0.,))
        @test H.choose_state(H.RabbitApproachPolicy(),o)==H.choose_state(H.StateMachinePolicy(),o)
    end
end
@testset "dense cover preference weakens with hunger" begin
    thin=(vegetation=(cover=.1,),);dense=(vegetation=(cover=.9,),)
    @test H.configured_rabbit_cover_bonus(dense,75.)>H.configured_rabbit_cover_bonus(thin,75.)
    @test H.configured_rabbit_cover_bonus(dense,75.)>H.configured_rabbit_cover_bonus(dense,40.)
    @test H.configured_rabbit_cover_bonus(dense,25.)==0.
    @test H.configured_rabbit_cover_bonus((vegetation=nothing,),75.)==0.
end
module DisabledCover
include_string(@__MODULE__,replace(read(joinpath(@__DIR__,"../../src/lw/configured_paths/rabbit_cover_foraging.jl"),String),"enabled=true"=>"enabled=false"))
end
@test DisabledCover.configured_rabbit_cover_bonus((vegetation=(cover=1.,),),75.)==0.
