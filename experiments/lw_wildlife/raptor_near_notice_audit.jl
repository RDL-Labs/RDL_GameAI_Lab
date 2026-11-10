using JSON3,Serialization,Random
const run_dir="C:/Users/ken_m/Documents/Codex/raptor150-base085-90d-20261110"
include("predator_generations.jl")
include("../../src/lw/configured_paths/raptor_trial.jl")
function audit()
 saved=deserialize(joinpath(run_dir,"checkpoints/day-080.jls"));s=saved.world;c=saved.cohort;b=saved.raptor
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 records=Any[]; traces=Any[]
 for t in s.ticks:1397365
  animal_trial_prepare!(s,c.predators,t;raptor=b,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  if b.mode==:hunt && b.target in (274,275,276,277)
   i=b.target
   push!(traces,(tick=t,id=i,seen_now=s.last_seen[i]==t,seen_actor=s.seen_actor[i],bird_actor=length(c.predators)+1,override=Int(s.overrides[i]),flee=Int(H.FLEE),burrow_before=G.configured_rabbit_in_burrow(s,i,t),nest_distance=hypot(s.animals.x[i]-s.life.nest[i][1],s.animals.z[i]-s.life.nest[i][2]),bird_distance=hypot(s.animals.x[i]-b.visual.body.x,s.animals.z[i]-b.visual.body.z)))
  end
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  old_attempts=b.attempts;old_interrupts=b.interrupted_meals
  configured_raptor_step!(b,s,c.predators,t)
  if b.attempts>old_attempts
   e=last(b.events);i=e.details.id;p=(b.visual.body.x,b.visual.body.z);q=(s.animals.x[i],s.animals.z[i])
   push!(records,(tick=t,kind=e.kind,id=i,probability=e.details.probability,food=b.food,alive=s.alive[i],burrow=G.configured_rabbit_in_burrow(s,i,t),distance=hypot(p[1]-q[1],p[2]-q[2]),clear=H.clear(s.world,q,q),los=P.los(s.world,p,q),age=(t-s.life.born[i])/17280,position=q))
  end
  if b.interrupted_meals>old_interrupts
   p=first(c.predators).visual.body
   push!(records,(tick=t,kind="interruption",food=b.food,predator_distance=hypot(p.x-b.visual.body.x,p.z-b.visual.body.z)))
  end
 end
 @assert all(i->records[i-1].kind!="miss" || records[i].kind ∉ ("miss","capture") || records[i].id!=records[i-1].id,2:length(records))
 result=(records=records,traces=traces,final=configured_raptor_report(b))
 write(joinpath(@__DIR__,"evidence/raptor-near-notice-day81.json"),JSON3.write(result))
 misses=filter(x->x.kind=="miss",records)
 println(JSON3.write((attempts=length(filter(x->x.kind in ("miss","capture"),records)),misses=length(misses),zero=count(x->x.probability==0,misses),burrow=count(x->x.burrow,misses),blocked=count(x->!x.clear,misses),los_blocked=count(x->!x.los,misses),distant=count(x->x.distance>2.5,misses),interruptions=filter(x->x.kind=="interruption",records))))
end
audit()