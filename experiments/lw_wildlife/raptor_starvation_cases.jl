using Serialization,JSON3,Random
const continuation="C:/Users/ken_m/Documents/Codex/raptor-near3-continue360d-20261110"
include(joinpath(continuation,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(continuation,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 rows=Any[]
 for day in (130,134,136,137,138,139,365,368,370,371,372,373,374,375,376,377)
  saved=deserialize(joinpath(continuation,"checkpoints/day-"*lpad(day-90,3,'0')*".jls"));s=saved.world;a=s.animals
  for i in (day<200 ? (166,) : (347,484,485,486,487))
   i<=length(s.alive) || continue
   k=H.cell(s.world,a.x[i],a.z[i]);near=Int[]
   for j in eachindex(s.world.grass)
    p=H.center(s.world,j);hypot(p[1]-a.x[i],p[2]-a.z[i])<=5 && push!(near,j)
   end
   for j in near;H.grass!(s.world,j,s.ticks);end
   push!(rows,(day,id=i,alive=s.alive[i],energy=a.energy[i],gut=a.gut[i],position=(a.x[i],a.z[i]),state=Int(a.state[i]),distance=a.distance[i],consumed=a.consumed[i],blocked=a.blocked[i],nursed=s.life.nursed_day[i],nest=s.life.nest[i],current_grass=s.world.grass[k],current_capacity=s.world.capacity[k],near_grass=sum(s.world.grass[near]),near_capacity=sum(s.world.capacity[near]),predator_position=(saved.cohort.predators[1].visual.body.x,saved.cohort.predators[1].visual.body.z),last_seen=s.last_seen[i],override=Int(s.overrides[i])))
  end
 end
 write(joinpath(@__DIR__,"evidence/raptor-starvation-cases.json"),JSON3.write(rows));println("saved ",length(rows)," rows")
end
audit()