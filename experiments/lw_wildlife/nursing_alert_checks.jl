using Test
include("predator_generations.jl")
@testset "alert versus nursing need" begin
 a=(x=[0.,1.],z=[0.,0.],energy=[85.,4.])
 s=(animals=a,seen_position=[(7.,0.),(0.,0.)])
 @test !G.configured_nursing_alert_evidence(s,1,[2]).allow
 a.energy[2]=1.
 @test G.configured_nursing_alert_evidence(s,1,[2]).allow
 s.seen_position[1]=(3.,0.)
 @test !G.configured_nursing_alert_evidence(s,1,[2]).allow
 a.energy[2]=0.
 @test !G.configured_nursing_alert_evidence(s,1,[2]).allow
 s.seen_position[1]=(10.,0.)
 @test G.configured_nursing_alert_evidence(s,1,[2]).allow
 @test G.V.reaction(3.,0.,true)==H.FLEE
 @test G.V.reaction(6.,.2,true)==H.FLEE
end
