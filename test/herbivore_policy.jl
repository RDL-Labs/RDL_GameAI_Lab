using Test, JSON3
include("../src/ecology/herbivore/Herbivores.jl")
const H=Herbivores

# A policy needs observations, not a World or Animals reference.
struct RestPolicy end
H.choose_state(::RestPolicy, observation)=H.REST
H.choose_target(::RestPolicy, observations, heading, previous_cell)=0

@testset "policy boundary" begin
    spec=JSON3.read(read(joinpath(@__DIR__,"../experiments/numeric_ecology/herbivore-cpu/map-spec.json"),String))
    w,a=H.build(spec)
    initial_x=copy(a.x); initial_z=copy(a.z)
    demand=zeros(length(w.grass)); ratio=similar(demand)
    requests=zeros(length(a.x)); active=Int[]
    for t in 0:99
        H.step!(w,a,t,demand,ratio,requests,active;policy=RestPolicy())
    end
    @test a.x==initial_x && a.z==initial_z
    @test all(==(H.REST),a.state)
    @test w.eaten==0 && all(iszero,a.consumed)
    @test all(==(100),a.counts[:,H.REST])
    observation=H.observe_state!(w,a,1,100,nothing)
    @test !observation.threat
    threatened=merge(observation,(threat=true,))
    @test H.choose_state(H.StateMachinePolicy(),threatened)==H.FLEE
    options=((cell=2,grass=1.,distance=1.,direction=0.),nothing,
             (cell=3,grass=1.,distance=1.,direction=0.))
    @test H.choose_target(H.StateMachinePolicy(),options,0.,0)==2
    @test H.choose_target(H.StateMachinePolicy(),options,0.,2)==3
    @test H.choose_target(H.StateMachinePolicy(),(nothing,nothing),0.,0)==0
end
