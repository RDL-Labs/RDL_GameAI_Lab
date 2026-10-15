using Test, JSON3, Random
include("Predators.jl")
const P=Predators; const H=P.H
spec=JSON3.read(read(joinpath(@__DIR__,"map-spec.json"),String))
@testset "predator perception and lifecycle" begin
    w,a=H.build(spec); p=P.spawn(w); alive=trues(30)
    empty!(w.obstacles); w.phase=0.
    p.x=-8.; p.z=6.; a.x[1]=-5.; a.z[1]=6.
    @test P.visible(w,p,a,1,0)
    push!(w.obstacles,H.RDLMigrationProbe.Circle(-6.5,6.,.5))
    @test !P.visible(w,p,a,1,0)
    empty!(w.obstacles)
    a.x[1]=40.; @test !P.visible(w,p,a,1,0)
    alive.=false; p.state=P.CHASE; p.target=1; p.seen_x=-5.; p.seen_z=6.; p.expires=20
    P.plan!(w,p,a,alive,19,MersenneTwister(1))
    @test p.state==P.CHASE
    P.plan!(w,p,a,alive,20,MersenneTwister(1))
    @test p.state==P.SEARCH && p.target==0
    p.state=P.ATTACK; p.timer=3; p.heading=0.; p.attacks=1
    a.x.=-7.; a.z.=6.; alive.=true; events=NamedTuple[]
    P.advance!(w,p,a,alive,21,MersenneTwister(1),events)
    @test length(events)==1
    @test p.state in (P.REST,P.RECOVER)
    @test count(!,alive)<=1
    @test p.captures+p.misses==1
    pos=(p.x,p.z)
    P.advance!(w,p,a,alive,22,MersenneTwister(1),events)
    @test (p.x,p.z)==pos && length(events)==1
    frozen=(a.x[1],a.z[1],a.energy[1],a.gut[1],sum(a.counts[1,:]))
    alive[1]=false
    H.step!(w,a,22,zeros(length(w.grass)),zeros(length(w.grass)),zeros(30),Int[];alive)
    @test frozen==(a.x[1],a.z[1],a.energy[1],a.gut[1],sum(a.counts[1,:]))
    # Direct escape is obstructed, but an unobstructed side step exists.
    w,a=H.build(spec); empty!(w.obstacles); a.x.=-8.; a.z.=6.
    push!(w.obstacles,H.RDLMigrationProbe.Circle(-8.65,6.,.2))
    H.step!(w,a,0,zeros(length(w.grass)),zeros(length(w.grass)),zeros(30),Int[];threat=(-7.,6.))
    @test a.distance[1]>0 && H.clear(w,(-8.,6.),(a.x[1],a.z[1]))
end
control=JSON3.read(read(joinpath(@__DIR__,"control/result.json"),String))
old=JSON3.read(read(joinpath(@__DIR__,"../herbivore-cpu/run/result.json"),String))
@testset "control parity" begin
    @test control.survivors==30
    @test control.grass_eaten==old.grass_eaten
    @test all(control.daily[i].rabbit_state_ticks==old.daily[i].state_ticks for i in 1:3)
    @test all(control.final[i].x==old.final[i].x && control.final[i].z==old.final[i].z for i in 1:30)
end
