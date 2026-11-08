include("nursing_supply_checks.jl")
const H=G.H
@testset "optional rabbit river crossing" begin
 s=reproductive_world();w=s.world;a=s.animals;p=H.RabbitSwimmingPolicy()
 z=6.;river=12+5sin((z-6)/22+w.phase)
 a.x[1]=river-2.;a.z[1]=z;a.energy[1]=50.;a.state[1]=H.SEARCH
 a.current_cell[1]=H.cell(w,a.x[1],z)
 candidate=H.configured_rabbit_swim_candidate(w,a,1,0,p)
 @test candidate!==nothing
 @test candidate.goal[1]>river
 @test !H.clear(w,(a.x[1],z),candidate.goal)
 a.energy[1]=1.
 @test H.configured_rabbit_swim_candidate(w,a,1,0,p)===nothing
 a.energy[1]=50.;p.trips[1]=candidate
 origin=a.x[1];energy=a.energy[1]
 for t in 0:100
  haskey(p.trips,1) || break
  @test H.configured_rabbit_swim_step!(p,w,a,1,t,nothing)
 end
 @test a.x[1]≈candidate.goal[1]
 @test p.counts[:arrived]==1 && p.counts[:swim_ticks]>0
 @test a.energy[1]<energy
 @test H.material(w.phase,a.x[1],a.z[1])!=H.WATER
 # Shore interruptions preserve nursing/escape state before action allocation.
 p.trips[1]=candidate
 @test H.configured_rabbit_swim_state(p,w,a,1,H.FLEE,[H.FLEE,0])==H.FLEE
 @test !haskey(p.trips,1) && p.counts[:interrupted]==1
 # In water, finish crossing rather than reverting to land collision rules.
 a.x[1]=river;p.trips[1]=candidate
 @test H.configured_rabbit_swim_state(p,w,a,1,H.FLEE,[H.FLEE,0])==H.SEARCH
 io=IOBuffer();serialize(io,p);seekstart(io);restored=deserialize(io)
 @test restored.trips==p.trips && restored.counts==p.counts
 @test H.rabbit_approach_base(restored) isa H.RabbitApproachPolicy
 # Integrated adult body/movement path and state accounting.
 s=reproductive_world();a=s.animals;w=s.world;p=H.RabbitSwimmingPolicy()
 a.x[1]=river-2.;a.z[1]=z;a.energy[1]=50.;a.gut[1]=0.
 a.current_cell[1]=H.cell(w,a.x[1],z);p.trips[1]=candidate
 for t in 0:100
  G.prepare!(s,[(100.,100.),(101.,100.),(102.,100.)],t)
  G.advance!(s,t;grazing_policy=p)
  p.counts[:arrived]>0 && break
 end
 @test p.counts[:arrived]==1
 @test a.x[1]≈candidate.goal[1]
 # Integrated movement: dependent young remain in the burrow, even with a trip.
 s=reproductive_world();G.rabbit_initial_young!(s,1,1);p=H.RabbitSwimmingPolicy()
 p.trips[3]=candidate;young=(s.animals.x[3],s.animals.z[3])
 G.prepare!(s,[(100.,100.),(101.,100.),(102.,100.)],0)
 G.advance!(s,0;grazing_policy=p)
 @test (s.animals.x[3],s.animals.z[3])==young
end

