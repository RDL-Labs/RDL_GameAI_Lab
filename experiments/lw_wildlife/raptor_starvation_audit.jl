using Serialization,JSON3,Random
const origin="C:/Users/ken_m/Documents/Codex/raptor150-near3-90d-20261110"
const continuation="C:/Users/ken_m/Documents/Codex/raptor-near3-continue360d-20261110"
include(joinpath(continuation,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(continuation,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 final=deserialize(joinpath(continuation,"checkpoints/day-360.jls"));s=final.world
 captured=Dict{Int,Any}()
 for root in (origin,continuation),line in eachline(joinpath(root,"daily.jsonl"))
  row=JSON3.read(line)
  for p in row.predators,e in p.events
   e.kind=="capture" && (captured[Int(e.id)]=(tick=Int(e.tick),source="ground"))
  end
  for e in row.raptor.events
   e.kind=="capture" && (captured[Int(e.details.id)]=(tick=Int(e.tick),source="bird"))
  end
 end
 deaths=Dict(r.id=>r for r in s.starvation_records)
 rows=map(s.starvation_records) do r
  cause=haskey(captured,r.mother) ? captured[r.mother] : haskey(deaths,r.mother) ? (tick=deaths[r.mother].tick,source="starvation") : nothing
  merge(r,(mother_death=cause,position=(s.animals.x[r.id],s.animals.z[r.id]),mother_final_position=r.mother>0 ? (s.animals.x[r.mother],s.animals.z[r.mother]) : nothing))
 end
 write(joinpath(@__DIR__,"evidence/raptor-starvation-450d.json"),JSON3.write(rows))
 println(JSON3.write(rows))
end
audit()