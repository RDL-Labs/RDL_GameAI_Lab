# Read-only checkpoint census; no simulation steps or observation mutations.
using Serialization, JSON3, Statistics
root=ARGS[1]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function census()
 rows=Any[];deaths=Any[];previous=nothing
 for day in 0:198
  saved=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls"));s=saved.world;a=s.animals;w=s.world
  west(i)=a.x[i]<12+5sin((a.z[i]-6)/22+w.phase)
  captures=Dict(e.id=>(actor=j,tick=e.tick) for (j,p) in enumerate(saved.cohort.predators) for e in p.visual.events if e.kind=="capture")
  born=previous===nothing ? Int[] : collect(length(previous.alive)+1:length(s.alive))
  dead=previous===nothing ? Int[] : [i for i in eachindex(s.alive) if !s.alive[i] && (i>length(previous.alive)||previous.alive[i])]
  for i in dead
   cause=haskey(captures,i) ? "capture" : a.energy[i]<=0 ? "starvation" : "unknown"
   push!(deaths,(day,id=i,west=west(i),cause,energy=a.energy[i],age_days=(s.ticks-s.life.born[i])/17280,mother=s.life.mother[i],capture=get(captures,i,nothing)))
  end
  regions=Any[]
  for side in (true,false)
   ids=[i for i in eachindex(s.alive) if s.alive[i]&&west(i)==side]
   cells=[k for k in eachindex(w.grass) if ((x,z)=H.center(w,k);x<12+5sin((z-6)/22+w.phase))==side]
   push!(regions,(side=side ? "west" : "east",alive=length(ids),births=count(i->west(i)==side,born),captures=count(i->west(i)==side&&haskey(captures,i),dead),starvation=count(i->west(i)==side&&!haskey(captures,i)&&a.energy[i]<=0,dead),pregnant=count(i->s.life.due[i]>0,ids),female=count(i->s.life.sex[i]==1,ids),mature_female=count(i->s.life.sex[i]==1 && s.ticks-s.life.born[i]>=150*17280,ids),mature_male=count(i->s.life.sex[i]==2 && s.ticks-s.life.born[i]>=150*17280,ids),grass=sum(w.grass[cells]),energy=isempty(ids) ? nothing : mean(a.energy[ids]),survivors=length(ids)<=10 ? [(id=i,energy=a.energy[i],age_days=(s.ticks-s.life.born[i])/17280,sex=s.life.sex[i],due=s.life.due[i]) for i in ids] : nothing))
  end
  if previous!==nothing
   @assert length(dead)==s.deaths-previous.deaths+sum(p.visual.body.captures for p in saved.cohort.predators)-previous.captures
  end
  push!(rows,(day,absolute_day=360+day,regions))
  previous=(alive=copy(s.alive),deaths=s.deaths,captures=sum(p.visual.body.captures for p in saved.cohort.predators))
  day%30==0 && (println("CENSUS ",day);flush(stdout))
 end
 write(ARGS[2],JSON3.write((rows,deaths,note="Daily checkpoint identities; capture events identify cause; other deaths require energy<=0. Day-end positions classify river bank.")))
end
census()

