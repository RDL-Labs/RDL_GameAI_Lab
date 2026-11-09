using JSON3,Serialization,Test
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function audit()
 saved=deserialize(joinpath(root,"checkpoints/day-236.jls"));before=deserialize(joinpath(root,"checkpoints/day-237.jls"));after=deserialize(joinpath(root,"checkpoints/day-238.jls"))
 s=saved.world;c=saved.cohort
 captured=Set(e.id for p in after.cohort.predators for e in p.visual.events if e.kind=="capture" && 327*17280<=e.tick<328*17280)
 ids=[i for i in eachindex(before.world.alive) if before.world.alive[i]&&!after.world.alive[i]&&!(i in captured)]
 @test length(ids)==94
 traces=Dict(string(i)=>Any[] for i in ids);deaths=Any[];maps=Any[]
 H.enable_rabbit_neighbor_batch!(s.world;gpu=true,automatic=true)
 for t in s.ticks:328*17280-1
  oldalive=copy(s.alive)
  if t%60==0
   for i in ids;s.alive[i] && push!(traces[string(i)],(tick=t,x=s.animals.x[i],z=s.animals.z[i],energy=s.animals.energy[i],state=H.STATES[s.animals.state[i]],gut=s.animals.gut[i]));end
  end
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  for i in ids
   oldalive[i]&&!s.alive[i] || continue
   a=s.animals;push!(traces[string(i)],(tick=t+1,x=a.x[i],z=a.z[i],energy=a.energy[i]))
   push!(deaths,(id=i,tick=t+1,age=(t-s.life.born[i])/17280,mother=s.life.mother[i],position=(a.x[i],a.z[i]),state=H.STATES[a.state[i]],children=[(id=j,position=(a.x[j],a.z[j]),energy=a.energy[j],age=(t-s.life.born[j])/17280) for j in eachindex(oldalive) if oldalive[j] && s.life.mother[j]==i && G.dependent(s.life,j,t)]))
  end
  if (t+1)%17280==0
   day=div(t+1,17280);animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
   expected=deserialize(joinpath(root,"checkpoints/day-"*lpad(day-90,3,'0')*".jls"));a=s.animals;b=expected.world.animals
   @test s.alive==expected.world.alive && a.x==b.x && a.z==b.z && a.energy==b.energy && a.counts==b.counts && s.world.grass==expected.world.world.grass
   push!(maps,(day,grass=copy(s.world.grass)));println("MATCH ",day);flush(stdout)
  end
 end
 w=s.world
 write(ARGS[2],JSON3.write((ids,traces,deaths,maps,world=(xmin=w.xmin,xmax=w.xmax,zmin=w.zmin,zmax=w.zmax,nx=w.nx,nz=w.nz,cellsize=w.cellsize,phase=w.phase,capacity=w.capacity,obstacles=[(x=o.x,z=o.z,radius=o.radius) for o in w.obstacles]))))
end
audit()
