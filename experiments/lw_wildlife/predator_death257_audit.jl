using Serialization,JSON3,Random
const death_root="C:/Users/ken_m/Documents/Codex/rabbit-fresh3000-20261110/run-v2"
include(joinpath(death_root,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(death_root,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 saved=deserialize(joinpath(death_root,"checkpoints/day-255.jls"));s=saved.world;c=saved.cohort;b=saved.raptor;p=first(c.predators)
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 counts=Dict{String,Int}();rows=Any[];moving=0;stationary=0;death=nothing
 for t in s.ticks:257*17280-1
  wasalive=p.alive;origin=(p.visual.body.x,p.visual.body.z)
  animal_trial_prepare!(s,c.predators,t;raptor=b,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  if wasalive
   key=string(p.mode);counts[key]=get(counts,key,0)+1
   if t%720==0;push!(rows,(tick=t,food=p.food,mode=key,position=origin,selected=first(c.minds).selected));end
  end
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  configured_raptor_step!(b,s,c.predators,t)
  if wasalive
   hypot(p.visual.body.x-origin[1],p.visual.body.z-origin[2])>1e-8 ? (moving+=1) : (stationary+=1)
   !p.alive && (death=(tick=t,day=t/17280,position=(p.visual.body.x,p.visual.body.z),food=p.food))
  end
 end
 expected=deserialize(joinpath(death_root,"checkpoints/day-257.jls"));ep=first(expected.cohort.predators)
 matched=p.food==ep.food && p.visual.body.x==ep.visual.body.x && p.visual.body.z==ep.visual.body.z
 result=(matched=matched,counts=counts,moving=moving,stationary=stationary,death=death,rows=rows,records=first(c.minds).records,local_counts=first(c.local_hunts).counts)
 write(joinpath(@__DIR__,"evidence/predator-death257.json"),JSON3.write(result));println(JSON3.write((matched=matched,counts=counts,moving=moving,stationary=stationary,death=death)))
end
audit()
