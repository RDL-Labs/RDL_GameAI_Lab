using Serialization,JSON3,Random
const audit_root="C:/Users/ken_m/Documents/Codex/raptor-west2306-360d-20261110/run"
include(joinpath(audit_root,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(audit_root,"source/src/lw/configured_paths/raptor_trial.jl"))
rows=Any[]
for (mother,days) in ((1972,[2307,2330,2336]),(1890,[2307,2324,2444]),(2015,[2307,2473,2477]))
 for day in days
  saved=deserialize(joinpath(audit_root,"checkpoints/day-"*lpad(day-2306,3,'0')*".jls"));s=saved.world
  haskey(saved.cohort.rabbit_approach.base.actors,mother)||continue
  m=saved.cohort.rabbit_approach.base.actors[mother]
  push!(rows,(mother=mother,day=day,position=(s.animals.x[mother],s.animals.z[mother]),H=[(cell=k,H=v,center=H.center(s.world,k)) for (k,v) in m.H if v>=30],records=m.records))
 end
end
write(joinpath(@__DIR__,"evidence/west-H-history.json"),JSON3.write(rows))
for r in rows;println(JSON3.write((mother=r.mother,day=r.day,position=r.position,H=r.H)));end
