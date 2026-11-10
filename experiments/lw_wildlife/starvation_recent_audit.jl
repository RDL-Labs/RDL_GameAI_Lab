using Serialization,JSON3,Random
const audit_root="C:/Users/ken_m/Documents/Codex/raptor-resume550-20261110/run"
include(joinpath(audit_root,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(audit_root,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 cutoff=1853
 saved=deserialize(joinpath(audit_root,"checkpoints/day-1303.jls"));s=saved.world
 captures=Dict{Int,Any}()
 for line in eachline(joinpath(audit_root,"daily.jsonl"))
  row=JSON3.read(line);row.absolute_day>cutoff && break
  for p in row.predators,e in p.events
   e.kind=="capture" && (captures[Int(e.id)]=(tick=Int(e.tick),day=div(Int(e.tick),17280)+1,source="ground"))
  end
  for e in row.raptor.events
   e.kind=="capture" && (captures[Int(e.details.id)]=(tick=Int(e.tick),day=div(Int(e.tick),17280)+1,source="bird"))
  end
 end
 rows=Any[]
 for r in s.starvation_records
  cutoff-90<r.day<=cutoff || continue
  maternal=get(captures,r.mother,nothing)
  maternal!==nothing && maternal.tick>r.tick && (maternal=nothing)
  push!(rows,merge(r,(mother_capture=maternal,position=(s.animals.x[r.id],s.animals.z[r.id]))))
 end
 write(joinpath(@__DIR__,"evidence/starvation-days1764-1853.json"),JSON3.write(rows))
 println(JSON3.write(rows))
end
audit()
