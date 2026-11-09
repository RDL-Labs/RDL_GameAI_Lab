using JSON3,Serialization,Test
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
# Observer-only instrumentation of the frozen target selector in this process.
# Reuse its actual observations/scores/chosen result; no extra observation or RNG call.
Core.eval(H,:(const AUDIT_CHOICES=Any[]))
source=read(joinpath(root,"source/src/ecology/herbivore/approach.jl"),String)
lo=findfirst("function target!(w,a,i,t,policy::RabbitApproachPolicy)",source).start
hi=findfirst("function approach_feedback!(policy::RabbitApproachPolicy",source).start
method=source[lo:prevind(source,hi)]
method=replace(method,"    o=observations[chosen]"=>"    i==32 && push!(AUDIT_CHOICES,(tick=t,position=(a.x[i],a.z[i]),heading=a.heading[i],previous=a.previous_cell[i],observations=observations,scores=scores,H=[get(m.H,o.cell,0.) for o in observations],pressure=pressure,chosen=chosen))\n    o=observations[chosen]")
Base.include_string(H,method,"observer_target_selector")
function audit()
 saved=deserialize(joinpath(root,"checkpoints/day-236.jls"));s=saved.world;c=saved.cohort;w=s.world;a=s.animals
 frames=Any[];states=Dict{String,Int}();trace=Any[];death=nothing
 H.enable_rabbit_neighbor_batch!(w;gpu=true,automatic=true)
 for t in s.ticks:328*17280-1
  if s.alive[32]
   if t%240==0
    grass=[min(w.capacity[k],w.grass[k]+w.capacity[k]*max(0,t-w.updated[k])/(2*17280)) for k in eachindex(w.grass)]
    push!(frames,(tick=t,x=a.x[32],z=a.z[32],energy=a.energy[32],gut=a.gut[32],state=H.STATES[a.state[32]],target=a.target[32],grass=grass,choice_index=length(H.AUDIT_CHOICES)))
   end
   t%60==0 && push!(trace,(tick=t,x=a.x[32],z=a.z[32],energy=a.energy[32]))
  end
  alive_before=s.alive[32]
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  override=s.overrides[32]
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  if alive_before
   label=H.STATES[a.state[32]]*"/override="*string(override);states[label]=get(states,label,0)+1
   if !s.alive[32]
    death=(tick=t+1,position=(a.x[32],a.z[32]))
    push!(trace,(tick=t+1,x=a.x[32],z=a.z[32],energy=a.energy[32]))
   end
  end
  if (t+1)%17280==0
   day=div(t+1,17280);animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
   expected=deserialize(joinpath(root,"checkpoints/day-"*lpad(day-90,3,'0')*".jls"));b=expected.world.animals
   @test s.alive==expected.world.alive && a.x==b.x && a.z==b.z && a.energy==b.energy && a.counts==b.counts && w.grass==expected.world.world.grass
   println("MATCH ",day);flush(stdout)
  end
 end
 children=[i for i in eachindex(s.alive) if s.life.mother[i]==32]
 write(ARGS[2],JSON3.write((frames,trace,choices=H.AUDIT_CHOICES,states,death,nest=s.life.nest[first(children)],world=(xmin=w.xmin,xmax=w.xmax,zmin=w.zmin,zmax=w.zmax,nx=w.nx,nz=w.nz,cellsize=w.cellsize,phase=w.phase,capacity=w.capacity,obstacles=[(x=o.x,z=o.z,radius=o.radius) for o in w.obstacles]))))
end
audit()

