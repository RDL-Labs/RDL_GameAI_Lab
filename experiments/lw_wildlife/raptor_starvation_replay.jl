using Serialization,JSON3,Random
const audit_run="C:/Users/ken_m/Documents/Codex/raptor-near3-continue360d-20261110"
include(joinpath(audit_run,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(audit_run,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit_case(day,ids)
 saved=deserialize(joinpath(audit_run,"checkpoints/day-"*lpad(day-90,3,'0')*".jls"));s=saved.world;c=saved.cohort;b=saved.raptor
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 rows=Any[]; totals=Dict(i=>Dict{String,Int}() for i in ids)
 for t in s.ticks:(day+1)*17280-1
  animal_trial_prepare!(s,c.predators,t;raptor=b,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  for i in ids
   s.alive[i] || continue
   key="override_"*string(s.overrides[i]);totals[i][key]=get(totals[i],key,0)+1
   if s.last_seen[i]==t
    key="seen_actor_"*string(s.seen_actor[i]);totals[i][key]=get(totals[i],key,0)+1
   end
   if t%720==0 || s.animals.energy[i]<0.02
    a=s.animals;p=first(c.predators).visual.body
    push!(rows,(tick=t,id=i,energy=a.energy[i],position=(a.x[i],a.z[i]),override=Int(s.overrides[i]),state=Int(a.state[i]),consumed=a.consumed[i],distance=a.distance[i],seen_actor=s.seen_actor[i],last_seen=s.last_seen[i],burrow=G.configured_rabbit_in_burrow(s,i,t),predator_distance=hypot(a.x[i]-p.x,a.z[i]-p.z),predator_mode=first(c.predators).mode,pending=i in G.configured_nursing_pending(s.life),nursed=s.life.nursed_day[i]))
   end
  end
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  configured_raptor_step!(b,s,c.predators,t)
 end
 expected=deserialize(joinpath(audit_run,"checkpoints/day-"*lpad(day+1-90,3,'0')*".jls"))
 matched=all(i->s.alive[i]==expected.world.alive[i] && s.animals.x[i]==expected.world.animals.x[i] && s.animals.energy[i]==expected.world.animals.energy[i],ids)
 return (day=day+1,matched,totals,rows)
end
results=[audit_case(138,(166,)),audit_case(376,(347,484,485,486,487))]
write(joinpath(@__DIR__,"evidence/raptor-starvation-replay.json"),JSON3.write(results))
for r in results;println(JSON3.write((day=r.day,matched=r.matched,totals=r.totals)));end
