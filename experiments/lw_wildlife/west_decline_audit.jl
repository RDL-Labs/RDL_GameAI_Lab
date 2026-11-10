using Serialization,JSON3,Random
const west_run="C:/Users/ken_m/Documents/Codex/raptor-resume550-20261110/run"
include(joinpath(west_run,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(west_run,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 load_day(d)=deserialize(joinpath(west_run,"checkpoints/day-"*lpad(d-550,3,'0')*".jls"))
 iswest(s,i)=s.animals.x[i]<12+5sin((s.animals.z[i]-6)/22+s.world.phase)
 prior=load_day(2170);rows=Any[]
 for day in 2171:2216
  saved=load_day(day);s=saved.world;old=prior.world
  dead=Int[];outgoing=Int[];incoming=Int[];born=Int[]
  for i in eachindex(old.alive)
   if old.alive[i] && iswest(old,i)
    !s.alive[i] ? push!(dead,i) : !iswest(s,i) ? push!(outgoing,i) : nothing
   elseif old.alive[i] && s.alive[i] && iswest(s,i)
    push!(incoming,i)
   end
  end
  for i in length(old.alive)+1:length(s.alive);s.alive[i] && iswest(s,i) && push!(born,i);end
  details=map(dead) do i
   starve=findfirst(r->r.id==i,s.starvation_records)
   ground=any(p->any(e->e.kind=="capture" && e.id==i,p.visual.events),saved.cohort.predators)
   bird=any(e->e.kind=="capture" && e.details.id==i,saved.raptor.events)
   (id=i,cause=starve!==nothing ? "starvation" : ground ? "ground" : bird ? "bird" : "unknown")
  end
  push!(rows,(day,west=count(i->s.alive[i] && iswest(s,i),eachindex(s.alive)),dead=details,outgoing,incoming,born))
  prior=saved
 end
 write(joinpath(@__DIR__,"evidence/west-decline-2170-2216.json"),JSON3.write(rows))
 println(JSON3.write((deaths=vcat([r.dead for r in rows]...),outgoing=sum(length(r.outgoing) for r in rows),incoming=sum(length(r.incoming) for r in rows),births=sum(length(r.born) for r in rows))))
end
audit()
