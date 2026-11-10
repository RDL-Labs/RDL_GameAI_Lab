using Serialization, JSON3, Random
const refuge_audit_run="C:/Users/ken_m/Documents/Codex/raptor-near3-continue360d-20261110"
include(joinpath(refuge_audit_run,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(refuge_audit_run,"source/src/lw/configured_paths/raptor_trial.jl"))
# Diagnostic-only fixed intervention. Never loaded by normal simulation.
# baseline preserves the frozen rule; release clears only in-burrow REST;
# disabled leaves the original ALERT/FLEE for the four focal young.
@eval G begin
 const refuge_audit_mode=Ref(:baseline)
 function configured_rabbit_refuge_response!(s,i,t)
  configured_rabbit_refuge_goal(s,i,t)===nothing && return
  s.overrides[i] in (H.ALERT,H.FLEE) || return
  mode=i in (484,485,486,487) ? refuge_audit_mode[] : :baseline
  mode==:disabled && return
  s.overrides[i]=configured_rabbit_in_burrow(s,i,t) ? (mode==:release ? UInt8(0) : H.REST) : H.FLEE
 end
end
function refuge_audit(mode)
 G.refuge_audit_mode[]=mode
 saved=deserialize(joinpath(refuge_audit_run,"checkpoints/day-286.jls"))
 s=saved.world;c=saved.cohort;b=saved.raptor;ids=(484,485,486,487)
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 initial_food=copy(s.animals.consumed);counts=Dict(i=>zeros(Int,6) for i in ids)
 for t in s.ticks:377*17280-1
  animal_trial_prepare!(s,c.predators,t;raptor=b,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  for i in ids;s.alive[i] && (counts[i][s.animals.state[i]]+=1);end
  configured_raptor_step!(b,s,c.predators,t)
 end
 expected=deserialize(joinpath(refuge_audit_run,"checkpoints/day-287.jls"))
 matched=all(i->s.alive[i]==expected.world.alive[i] && s.animals.energy[i]==expected.world.animals.energy[i] && s.animals.x[i]==expected.world.animals.x[i],ids)
 result=(mode,matched,starvation=filter(r->r.id in ids,s.starvation_records),animals=[(id=i,alive=s.alive[i],energy=s.animals.energy[i],consumed=s.animals.consumed[i]-initial_food[i],counts=counts[i],position=(s.animals.x[i],s.animals.z[i]),nursed=s.life.nursed_day[i]) for i in ids])
 mode==:baseline && @assert matched
 result
end
results=refuge_audit.((:baseline,:release,:disabled))
write(joinpath(@__DIR__,"evidence/raptor-refuge-fixed-audit.json"),JSON3.write(results))
println(JSON3.write(results))

