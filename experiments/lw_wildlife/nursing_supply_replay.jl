# Counterfactual using current implementation, same saved day62, no expected-state equality.
using Serialization,JSON3
include("predator_generations.jl")
function trial()
 root=ARGS[1];saved=deserialize(joinpath(root,"checkpoints/day-062.jls"));s=saved.world;c=saved.cohort
 @assert isempty(c.predators)
 initial=deepcopy(s);events=Any[];daily=Any[];mother=12;kids=[913,914,915]
 for t in s.ticks:(360+65)*17280-1
  before=s.animals.energy[913]
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  if s.animals.energy[913]>before
   push!(events,(day=(t+1)/17280-360,before,after=s.animals.energy[913],mother_energy=s.animals.energy[mother]))
  end
  if (t+1)%17280==0
   day=div(t+1,17280)-360
   animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds)
   baseline=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world
   measure(w)=(alive=count(w.alive),children_alive=collect(w.alive[kids]),children_energy=collect(w.animals.energy[kids]),mother_energy=w.animals.energy[mother],mother_eaten=w.animals.consumed[mother]-initial.animals.consumed[mother],mother_distance=w.animals.distance[mother]-initial.animals.distance[mother])
   row=(day,current=measure(s),baseline=measure(baseline));push!(daily,row);println(JSON3.write(row));flush(stdout)
  end
 end
 write(ARGS[2],JSON3.write((conditions=G.RABBIT_NURSING_PLAN,daily,events)))
end
trial()
