using JSON3,Serialization,Test
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function audit()
 saved=deserialize(joinpath(root,"checkpoints/day-071.jls"));s=saved.world;c=saved.cohort;a=s.animals;i=71
 samples=Any[];laststate=0;lastcell=0
 H.enable_rabbit_neighbor_batch!(s.world;gpu=true,automatic=true)
 for t in s.ticks:72*17280-1
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  k=H.cell(s.world,a.x[i],a.z[i])
  if s.alive[i] && (t>=1233900 || t%60==0 || a.state[i]!=laststate || k!=lastcell)
   push!(samples,(tick=t,energy=a.energy[i],state=H.STATES[a.state[i]],override=s.overrides[i],position=(a.x[i],a.z[i]),cell=k,capacity=s.world.capacity[k],target=a.target[i],blocked=a.blocked[i],seen_actor=s.seen_actor[i],seen_position=s.seen_position[i],last_seen=s.last_seen[i],consumed=a.consumed[i]))
  end
  laststate=a.state[i];lastcell=k
 end
 animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
 expected=deserialize(joinpath(root,"checkpoints/day-072.jls")).world
 @test s.alive==expected.alive && a.x==expected.animals.x && a.energy==expected.animals.energy && s.world.grass==expected.world.grass
 w=deepcopy(s.world);neighbors=H.observe_neighbors!(w,a,i,s.ticks)
 k=H.cell(w,a.x[i],a.z[i]);pos=(a.x[i],a.z[i]);target=a.target[i]
 geometry=(xmin=w.xmin,zmin=w.zmin,nx=w.nx,nz=w.nz,cellsize=w.cellsize,phase=w.phase,capacity=w.capacity,short=w.layers.short,walkable=w.walkable)
 write(ARGS[2],JSON3.write((;verified=true,samples,neighbors,geometry,final=(position=pos,cell=k,target,target_position=target>0 ? H.center(w,target) : nothing),obstacles=[(x=o.x,z=o.z,radius=o.radius,distance=hypot(pos[1]-o.x,pos[2]-o.z)) for o in w.obstacles if hypot(pos[1]-o.x,pos[2]-o.z)<o.radius+12])))
end
audit()
