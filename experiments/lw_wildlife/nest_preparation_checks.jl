include("reproductive_condition_checks.jl")
@testset "local nest preparation and actual birth site" begin
 s=reproductive_world();s.life.due[1]=3R.day_ticks;s.life.litter[1]=3
 s.animals.energy[1]=85.;s.animals.sleepy[1]=0.;s.animals.state[1]=G.H.SEARCH
 origin=(s.animals.x[1],s.animals.z[1]);replica=deepcopy(s)
 candidates=G.configured_rabbit_nest_candidates(s,1,0)
 @test !isempty(candidates)
 @test all(c->hypot(c.position[1]-origin[1],c.position[2]-origin[2])<=8,candidates)
 @test all(c->G.H.clear(s.world,origin,c.position),candidates)
 # Modifying invisible distant food must not change candidates.
 distant=deepcopy(s)
 for k in eachindex(distant.world.grass)
  p=G.H.center(distant.world,k)
  hypot(p[1]-origin[1],p[2]-origin[2])>8 && (distant.world.grass[k]=0.)
 end
 @test candidates==G.configured_rabbit_nest_candidates(distant,1,0)
 disabled=deepcopy(s);G.configured_rabbit_nest_preparation!(disabled,0;enabled=false)
 @test disabled.life.nest==s.life.nest && disabled.overrides==s.overrides
 G.configured_rabbit_nest_preparation!(s,0);G.configured_rabbit_nest_preparation!(replica,0)
 @test s.life.nest==replica.life.nest
 @test origin==(s.animals.x[1],s.animals.z[1])
 chosen=s.life.nest[1]
 fill!(s.overrides,0);G.configured_rabbit_nest_preparation!(s,1)
 @test s.life.nest[1]==chosen
 s.overrides[1]=G.H.FLEE;G.configured_rabbit_nest_preparation!(s,2)
 @test s.overrides[1]==G.H.FLEE
 s.overrides[1]=0;s.animals.energy[1]=40.;G.configured_rabbit_nest_preparation!(s,3)
 @test s.overrides[1]==0
 s.animals.energy[1]=85.;s.animals.state[1]=G.H.SLEEP;G.configured_rabbit_nest_preparation!(s,4)
 @test s.overrides[1]==0
 # A prepared birth still occurs at the actual position; no teleport to the remembered goal.
 s.life.nest[1]=(origin[1]+2.,origin[2]);s.life.invested[1]=24.
 G.rabbit_birth!(s,1,3R.day_ticks)
 @test all(i->s.life.nest[i]==origin && (s.animals.x[i],s.animals.z[i])==origin,3:5)
 io=IOBuffer();serialize(io,replica);seekstart(io);resumed=deserialize(io)
 @test resumed.life.nest==replica.life.nest
end
@testset "nest target drives ordinary movement" begin
 s=reproductive_world();s.ticks=1;s.life.due[1]=3R.day_ticks;s.life.nest[1]=(-6.,6.)
 s.animals.energy[1]=85.;s.animals.sleepy[1]=0.;s.animals.state[1]=G.H.SEARCH
 initial_distance=hypot(s.animals.x[1]+6,s.animals.z[1]-6)
 humans=[(1000.,1000.) for _ in s.previous_humans]
 for t in 1:20
  old=(s.animals.x[1],s.animals.z[1])
  G.prepare!(s,humans,t);G.advance!(s,t)
  @test hypot(s.animals.x[1]-old[1],s.animals.z[1]-old[2])<=.2+1e-10
 end
 @test hypot(s.animals.x[1]+6,s.animals.z[1]-6)<initial_distance
end
