using Test, JSON3
include("Herbivores.jl")
using .Herbivores
const H=Herbivores
spec=JSON3.read(read(joinpath(@__DIR__,"map-spec.json"),String))
@testset "herbivore transitions and resource allocation" begin
    @test H.choose_state(H.SEARCH,50.,0.,0.,2.,false)==H.GRAZE
    @test H.choose_state(H.GRAZE,50.,0.,0.,0.,false)==H.SEARCH
    @test H.choose_state(H.GRAZE,90.,1.,0.,2.,false)==H.REST
    @test H.choose_state(H.SEARCH,70.,1.,1.1,2.,false)==H.SLEEP
    @test H.choose_state(H.SLEEP,70.,1.,.5,2.,false)==H.SLEEP
    @test H.choose_state(H.SLEEP,70.,1.,.1,2.,false)!=H.SLEEP
    @test H.choose_state(H.SLEEP,70.,1.,1.1,2.,true)==H.FLEE
    w,a=H.build(spec)
    @test length(a.x)==30
    @test count(>(0),w.capacity)>2000
    @test all(w.capacity[k]==0 for k in eachindex(w.capacity) if w.material[k] in (H.WATER,H.ROCK) || !w.walkable[k])
    k=H.cell(w,a.x[1],a.z[1]); w.grass[k]=.15
    a.x.=a.x[1]; a.z.=a.z[1]
    H.step!(w,a,0,zeros(length(w.grass)),zeros(length(w.grass)),zeros(30),Int[])
    @test all(x->isapprox(x,.005;atol=1e-12),a.consumed)
    @test isapprox(w.eaten,.15;atol=1e-12)
    @test w.grass[k]>=0
    w1,a1=H.build(spec); w2,a2=H.build(spec)
    w1.grass[k]=0; w2.grass[k]=0
    H.grass!(w1,k,100); H.grass!(w1,k,200)
    H.grass!(w2,k,200)
    @test isapprox(w1.grass[k],w2.grass[k];atol=1e-12)
    @test isapprox(w1.grown,w2.grown;atol=1e-12)
    @test_throws ErrorException H.grass!(w1,k,199)
    dry,animals=H.build(spec;grass_scale=0.)
    d=zeros(length(dry.grass)); ratio=similar(d); req=zeros(30); active=Int[]
    for t in 0:99; H.step!(dry,animals,t,d,ratio,req,active); end
    @test all(>(0),animals.distance)
    @test sum(animals.consumed)==0
    @test all(isfinite,animals.energy)
    danger,animals=H.build(spec)
    oldx=animals.x[1]; oldz=animals.z[1]
    H.step!(danger,animals,0,zeros(length(danger.grass)),zeros(length(danger.grass)),zeros(30),Int[];threat=(oldx+1,oldz))
    @test animals.state[1]==H.FLEE
    @test hypot(animals.x[1]-(oldx+1),animals.z[1]-oldz)>1
end
