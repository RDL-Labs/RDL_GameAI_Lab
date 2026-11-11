using Serialization,JSON3,Random
const side_root="C:/Users/ken_m/Documents/Codex/rabbit-fresh3000-20261110/run-v2"
include(joinpath(side_root,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(side_root,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 load_day(d)=deserialize(joinpath(side_root,"checkpoints/day-"*lpad(d,3,'0')*".jls"))
 prior=load_day(0);initial=prior;rows=Any[]
 west(s,p)=p[1]<12+5sin((p[2]-6)/22+s.world.phase)
 pos(s,i)=(s.animals.x[i],s.animals.z[i])
 for day in 1:171
  saved=load_day(day);s=saved.world;old=prior.world
  dead=Any[];incoming=Int[];outgoing=Int[];births=Any[]
  for i in eachindex(old.alive)
   old.alive[i] || continue
   if !s.alive[i]
    cause=any(r->r.id==i,s.starvation_records) ? "starvation" : any(p->any(e->e.kind=="capture" && e.id==i,p.visual.events),saved.cohort.predators) ? "ground" : any(e->e.kind=="capture" && e.details.id==i,saved.raptor.events) ? "bird" : "unknown"
    push!(dead,(id=i,side=west(s,pos(s,i)) ? "west" : "east",previous_side=west(old,pos(old,i)) ? "west" : "east",cause=cause))
   elseif west(old,pos(old,i))!=west(s,pos(s,i))
    push!(west(s,pos(s,i)) ? incoming : outgoing,i)
   end
  end
  for i in length(old.alive)+1:length(s.alive)
   push!(births,(id=i,side=west(s,s.initial_positions[i]) ? "west" : "east",alive=s.alive[i]))
  end
  p=first(saved.cohort.predators).visual.body
  push!(rows,(day=day,dead=dead,births=births,incoming=incoming,outgoing=outgoing,predator=(p.x,p.z),predator_west=west(s,(p.x,p.z))))
  prior=saved
 end
 p=first(initial.cohort.predators).visual.body
 summary=Any[]
 for (lo,hi) in ((1,90),(91,171))
  block=filter(r->lo<=r.day<=hi,rows)
  push!(summary,(from=lo,to=hi,deaths=Dict(side=>Dict(c=>count(e->e.side==side && e.cause==c,[e for r in block for e in r.dead]) for c in ("ground","bird","starvation","unknown")) for side in ("west","east")),births=Dict(side=>count(e->e.side==side,[e for r in block for e in r.births]) for side in ("west","east")),east_to_west=sum(length(r.incoming) for r in block),west_to_east=sum(length(r.outgoing) for r in block),predator_west_dayends=count(r->r.predator_west,block)))
 end
 result=(initial_predator=(p.x,p.z),summary=summary,rows=rows)
 write(joinpath(@__DIR__,"evidence/fresh171-side-audit.json"),JSON3.write(result));println(JSON3.write((initial_predator=result.initial_predator,summary=summary)))
end
audit()
