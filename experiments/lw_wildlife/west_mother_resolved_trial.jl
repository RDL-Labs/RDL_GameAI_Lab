using Serialization,JSON3,Random
const audit_root="C:/Users/ken_m/Documents/Codex/raptor-west2306-360d-20261110/run"
include(joinpath(@__DIR__,"predator_generations.jl"))
include(joinpath(@__DIR__,"../../src/lw/configured_paths/raptor_trial.jl"))
function audit_crossing(day,mother)
 saved=deserialize(joinpath(audit_root,"checkpoints/day-"*lpad(day-1-2306,3,'0')*".jls"));s=saved.world;c=saved.cohort;b=saved.raptor
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 policy=c.rabbit_approach; rows=Any[]
 for t in s.ticks:day*17280-1
  animal_trial_prepare!(s,c.predators,t;raptor=b,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  hadtrip=haskey(policy.trips,mother);a=s.animals
  before=(position=(a.x[mother],a.z[mother]),energy=a.energy[mother],state=Int(a.state[mother]),override=Int(s.overrides[mother]))
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=policy)
  if !hadtrip && haskey(policy.trips,mother)
   memory=H.approach_memory(policy.base,mother)
   children=[j for j in eachindex(s.alive) if s.alive[j] && s.life.mother[j]==mother && G.dependent(s.life,j,t)]
   push!(rows,(tick=t,mother=mother,before=before,trip=policy.trips[mother],local_H=isempty(memory.H) ? 0. : maximum(values(memory.H)),children=[(id=j,energy=a.energy[j],position=(a.x[j],a.z[j])) for j in children]))
  end
  configured_raptor_step!(b,s,c.predators,t)
 end
 expected=deserialize(joinpath(audit_root,"checkpoints/day-"*lpad(day-2306,3,'0')*".jls"))
 (day=day,mother=mother,matched=s.animals.x[mother]==expected.world.animals.x[mother] && s.animals.energy[mother]==expected.world.animals.energy[mother],rows=rows,final=(alive=s.alive[mother],energy=s.animals.energy[mother],position=(s.animals.x[mother],s.animals.z[mother]),parent_H=H.approach_memory(policy.base,mother).food_pressure.H,local_H=maximum(values(H.approach_memory(policy.base,mother).H);init=0.)))
end
results=[audit_crossing(2337,1972),audit_crossing(2445,1890),audit_crossing(2478,2015)]
write(joinpath(@__DIR__,"evidence/west-mother-crossing-resolved.json"),JSON3.write(results))
println(JSON3.write(results))

