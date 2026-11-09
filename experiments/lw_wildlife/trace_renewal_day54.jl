using JSON3,Serialization,Test
root=ARGS[1]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function trace_day()
 saved=deserialize(joinpath(root,"checkpoints/day-053.jls"));expected=deserialize(joinpath(root,"checkpoints/day-054.jls"))
 s=saved.world;c=saved.cohort;a=s.animals;b=expected.world.animals
 captured=Set(e.id for p in expected.cohort.predators for e in p.visual.events if e.kind=="capture" && 53*17280<=e.tick<54*17280)
 dead=[i for i in eachindex(s.alive) if s.alive[i]&&!expected.world.alive[i]&&!(i in captured)]
 survivors=[i for i in eachindex(s.alive) if s.alive[i]&&expected.world.alive[i]]
 sort!(survivors;by=i->b.distance[i]-a.distance[i])
 ids=unique(vcat([survivors[end],survivors[cld(length(survivors),2)],survivors[1]],dead[1:1]))
 roles=["largest movement","median movement","smallest movement","starved"]
 traces=Dict(string(i)=>Any[] for i in ids)
 w=s.world;bg=deepcopy(w);grass=[H.grass!(bg,k,s.ticks) for k in eachindex(bg.grass)]
 geometry=(xmin=w.xmin,xmax=w.xmax,zmin=w.zmin,zmax=w.zmax,nx=w.nx,nz=w.nz,cellsize=w.cellsize,phase=w.phase,capacity=w.capacity,short=bg.layers.short,obstacles=[(x=o.x,z=o.z,radius=o.radius) for o in w.obstacles])
 H.enable_rabbit_neighbor_batch!(w;gpu=true,automatic=true)
 for t in s.ticks:54*17280-1
  if t%12==0
   for i in ids;s.alive[i]&&push!(traces[string(i)],(tick=t,x=a.x[i],z=a.z[i],energy=a.energy[i],state=H.STATES[a.state[i]]));end
  end
  oldalive=copy(s.alive)
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  for i in ids
   if oldalive[i]&&!s.alive[i];push!(traces[string(i)],(tick=t+1,x=a.x[i],z=a.z[i],energy=a.energy[i],state="dead"));end
  end
 end
 animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
 @test s.alive==expected.world.alive && a.x==b.x && a.z==b.z && a.energy==b.energy && a.counts==b.counts && w.grass==expected.world.world.grass
 initial=saved # mutated; use clean initial for deltas
 initial=deserialize(joinpath(root,"checkpoints/day-053.jls")).world
 summaries=[(id=i,role=roles[j],distance=a.distance[i]-initial.animals.distance[i],start_energy=initial.animals.energy[i],end_energy=a.energy[i],alive=s.alive[i],age=(53*17280-s.life.born[i])/17280,states=a.counts[i,:]-initial.animals.counts[i,:]) for (j,i) in enumerate(ids)]
 write(ARGS[2],JSON3.write((day=54,verified=true,geometry,traces,summaries)))
 println(JSON3.write(summaries))
end
trace_day()
