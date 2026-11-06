using Test
include("../../src/lw/LW.jl")
@testset "collapse gate is not death and physiology continues" begin
 a=first(LW.IDS);w=LW.world(true);w.bodies[a]=LW.Body(10.,0.,0.,0.)
 @test LW.configured_collapse_active(w.bodies[a])
 @test !LW.configured_collapse_active(w.bodies[a];enabled=false)
 map=LW.D();counts=LW.D(a=>LW.D());events=Any[];previous=LW.D()
 for now in (0,1_000_000)
  LW.configured_collapse_tick!(map,w,a,counts,events,previous,now)
 end
 @test counts[a]["collapsed"]==2 && length(events)==1
 @test map["collapse_gate"]["entries"]==1
 @test map["collapse_gate"]["blocked_ticks"]==2
 guts=Dict(x=>LW.RDLBody.Digestion() for x in LW.IDS)
 LW.RDLBody.ingest!(guts[a],1,0.,0)
 LW.advance_physiology!(w,Dict(x=>0. for x in LW.IDS),guts,true)
 @test w.bodies[a].reserve>0
 @test !LW.configured_collapse_active(w.bodies[a])
end
