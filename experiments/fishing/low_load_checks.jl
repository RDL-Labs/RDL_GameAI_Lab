using Test
include("../../src/body/RDLBody.jl")
using .RDLBody
import .RDLBody: step
@testset "low load shore fishing" begin
 b=Body(10.,.5,90.,0.)
 f,status,distance,delta=step(b,"fish",0)
 p,_,_,_=step(b,"process_food",0)
 @test status=="worked"
 @test distance==0
 @test b.reserve-f.reserve ≈ (b.reserve-p.reserve)/4
 @test f.strain < b.strain < p.strain
 @test f.burst==b.burst && f.damage==b.damage
 for _ in 1:180;b=step(b,"fish",0)[1];end
 @test b.reserve ≈ 90-180*.025*RS
 @test b.strain ≈ .5-180*.015*SS
 @test step(Body(10.,0.,90.,0.),"fish",0)[1].strain==0
 @test step(Body(10.,.5,0.,0.),"fish",0)[2]=="body_limited"
 @test step(Body(10.,1.,90.,0.),"fish",0)[2]=="body_limited"
 @test step(Body(0.,.5,90.,1.),"fish",0)[2]=="body_limited"
 low=Body(10.,.5,10.,0.)
 @test low.strain-step(low,"fish",0)[1].strain ≈ .015*SS*.5
 @test metabolize(f,1).reserve < f.reserve
end
