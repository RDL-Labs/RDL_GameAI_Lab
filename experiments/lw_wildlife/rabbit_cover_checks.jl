using Test
include("../../src/ecology/motion-vision-cpu/Herbivores.jl")
const H=Herbivores
@testset "cover preference preserves all state decisions" begin
    for old in UInt8.(1:6), energy in (10.,25.,65.,85.), grass in (0.,.004,.01,1.), threat in (false,true)
        o=(old=old,energy=energy,gut=0.,sleepy=.3,grass=grass,threat=threat,vegetation=(cover=0.,density=1.,))
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
@testset "sparse departure and hunger boundary" begin
    obs(e,d;threat=false)=(old=H.GRAZE,energy=e,gut=0.,sleepy=0.,grass=1.,threat=threat,vegetation=(cover=0.,density=d))
    @test H.choose_state(H.RabbitApproachPolicy(),obs(75.,.03))==H.SEARCH
    @test H.choose_state(H.RabbitApproachPolicy(),obs(25.,.03))==H.GRAZE
    @test H.choose_state(H.RabbitApproachPolicy(),obs(25.,.004))==H.SEARCH
    @test H.choose_state(H.RabbitApproachPolicy(),obs(25.,.005))==H.GRAZE
    @test H.choose_state(H.RabbitApproachPolicy(),obs(75.,.03;threat=true))==H.FLEE
    @test H.configured_rabbit_sparse_state(H.SLEEP,obs(75.,0.))==H.SLEEP
    @test H.configured_rabbit_sparse_state(H.REST,obs(75.,0.))==H.REST
    @test H.configured_rabbit_sparse_state(H.GRAZE,(energy=75.,vegetation=nothing))==H.GRAZE
end
module DisabledSparse
const GRAZE=UInt8(2);const SEARCH=UInt8(1)
include_string(@__MODULE__,replace(read(joinpath(@__DIR__,"../../src/lw/configured_paths/rabbit_sparse_departure.jl"),String),"enabled=true"=>"enabled=false"))
end
@test DisabledSparse.configured_rabbit_sparse_state(H.GRAZE,(energy=75.,vegetation=(density=0.,)))==H.GRAZE
