using Serialization,JSON3,Random
const westdeath_root="C:/Users/ken_m/Documents/Codex/raptor-west2306-360d-20261110/run"
include(joinpath(westdeath_root,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(westdeath_root,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 load_day(d)=deserialize(joinpath(westdeath_root,"checkpoints/day-"*lpad(d-2306,3,'0')*".jls"))
 final=load_day(2666);ids=vcat(collect(2132:2137),collect(2219:2223),collect(2245:2248))
 deaths=filter(r->r.id in ids,final.world.starvation_records)
 captures=Dict{Int,Any}()
 for line in eachline(joinpath(westdeath_root,"daily.jsonl"))
  r=JSON3.read(line)
  for p in r.predators,e in p.events;e.kind=="capture" && (captures[Int(e.id)]=(day=div(e.tick,17280)+1,tick=e.tick,source="ground"));end
  for e in r.raptor.events;e.kind=="capture" && (captures[Int(e.details.id)]=(day=div(e.tick,17280)+1,tick=e.tick,source="bird"));end
 end
 summary=[merge(r,(mother_capture=get(captures,r.mother,nothing),)) for r in deaths]
 cases=Any[]
 for (day,child) in ((2339,2132),(2447,2219),(2480,2245))
  r=only(filter(r->r.id==child,deaths));mother=r.mother
  for d in day-3:day
   saved=load_day(d);s=saved.world;a=s.animals
   for i in (child,mother)
    nearby=[k for k in eachindex(s.world.grass) if hypot(H.center(s.world,k)[1]-a.x[i],H.center(s.world,k)[2]-a.z[i])<=5]
    for k in nearby;H.grass!(s.world,k,s.ticks);end
    push!(cases,(day=d,id=i,alive=s.alive[i],energy=a.energy[i],position=(a.x[i],a.z[i]),nest=s.life.nest[i],state=Int(a.state[i]),override=Int(s.overrides[i]),distance=a.distance[i],consumed=a.consumed[i],nursed=s.life.nursed_day[i],blocked=a.blocked[i],grass=sum(s.world.grass[nearby]),capacity=sum(s.world.capacity[nearby])))
   end
  end
 end
 write(joinpath(@__DIR__,"evidence/west-starvation-360.json"),JSON3.write((summary,cases)))
 println(JSON3.write(summary))
end
audit()
