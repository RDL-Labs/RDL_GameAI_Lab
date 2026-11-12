using JSON3, Serialization, Test, SHA
include("../../src/ecology/lw_grazing/LWGrazing.jl")
const G=LWGrazing
const H=G.H
function fixture()
    input=JSON3.read(read(joinpath(@__DIR__,"ecology_dual_input.json"),String))
    scene=merge((;pairs(input.scene)...),(positions=Tuple{Float64,Float64}[],))
    G.build(scene,input.clock)
end
function signature(state)
    io=IOBuffer();serialize(io,state);bytes2hex(sha256(take!(io)))
end
@testset "Historical neighbor scratch lifecycle" begin
    s=fixture();a=s.animals;policy=H.StateMachinePolicy()
    b=H.enable_rabbit_neighbor_batch!(s.world;audit=true)
    a.state.=H.SEARCH;a.target.=0
    H.prepare_rabbit_neighbor_batch!(s.world,a,0,policy,s.alive,nothing)
    @test !isempty(b.touched)
    for i in b.touched
        p=(a.x[i],a.z[i]);k=H.cell(s.world,p...)
        for (dx,dz) in H.OFFSETS
            ix=mod(k-1,s.world.nx)+1+dx;iz=div(k-1,s.world.nx)+1+dz
            1<=ix<=s.world.nx && 1<=iz<=s.world.nz || continue
            j=ix+(iz-1)*s.world.nx;q=H.center(s.world,j)
            @test H.rabbit_neighbor_clear(s.world,a,i,j,0,p,q)==H.clear(s.world,p,q)
        end
    end
    prior=copy(b.touched);s.alive[first(prior)]=false;a.state.=H.REST
    H.prepare_rabbit_neighbor_batch!(s.world,a,0,policy,s.alive,nothing)
    @test isempty(b.touched) # even repeated tick must invalidate old slots
    @test all(iszero,b.slots)
    # Actual birth grows all permanent arrays and mother/child references.
    mother=findfirst(s.alive);old_n=length(s.alive)
    s.life.litter[mother]=2;s.life.invested[mother]=20.
    G.rabbit_birth!(s,mother,1)
    @test length(s.alive)==old_n+2
    @test all(==(mother),s.life.mother[old_n+1:end])
    a.state.=H.SEARCH
    H.prepare_rabbit_neighbor_batch!(s.world,a,1,policy,s.alive,nothing)
    @test size(b.slots,2)>=length(s.alive)
    @test !(first(prior) in b.touched)
    @test old_n+2 in b.touched
    capacity=size(b.slots,2);queries=b.queries
    s.life.litter[mother]=1;s.life.invested[mother]=10.
    G.rabbit_birth!(s,mother,2)
    H.prepare_rabbit_neighbor_batch!(s.world,a,2,policy,s.alive,nothing)
    @test size(b.slots,2)==capacity && b.queries===queries
    # Restore body state, then reconstruct the external scratch from scratch.
    io=IOBuffer();serialize(io,s);seekstart(io);restored=deserialize(io)
    H.disable_rabbit_neighbor_gpu!()
    rebuilt=H.enable_rabbit_neighbor_batch!(restored.world;audit=true)
    H.prepare_rabbit_neighbor_batch!(restored.world,restored.animals,3,policy,restored.alive,nothing)
    @test rebuilt.touched==b.touched
    @test signature(restored)==signature(s)
    H.disable_rabbit_neighbor_gpu!()
end
function replay!(s,ticks)
    policy=H.RabbitApproachPolicy()
    for t in s.ticks:s.ticks+ticks-1
        G.prepare!(s,Tuple{Float64,Float64}[],t)
        G.advance!(s,t;grazing_policy=policy)
    end
    (s,policy)
end
@testset "Short body, resource, memory and RNG replay" begin
    original=fixture()
    # Exercise day-boundary reproduction and dependent-young processing.
    original.ticks=G.RABBIT_LIFE.day_ticks-64
    reference=replay!(deepcopy(original),256)
    cached=deepcopy(original)
    H.enable_rabbit_neighbor_batch!(cached.world;audit=true)
    actual=replay!(cached,256)
    @test signature(reference)==signature(actual)
    H.disable_rabbit_neighbor_gpu!()
end
