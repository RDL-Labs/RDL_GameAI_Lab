# Read-only audit: RUN_DIRECTORY OUTPUT_JSON. Loads the run's frozen modules.
# Eligible/nearby counts are end-of-day snapshots, excluding receptivity/season;
# they are not exact counts at the daily conception decision.
using JSON3, Serialization, Statistics
root=ARGS[1]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
rows=Any[]
completed=JSON3.read(read(joinpath(root,"completed.json"),String))
for day in 0:completed.days
    saved=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls"))
    s=saved.world;l=s.life;a=s.animals;t=day*G.RABBIT_LIFE.day_ticks
    alive=findall(s.alive)
    mature=[i for i in alive if t-l.born[i]>=G.RABBIT_LIFE.maturity_days*G.RABBIT_LIFE.day_ticks]
    females=[i for i in mature if l.sex[i]==1];males=[i for i in mature if l.sex[i]==2]
    available=[i for i in females if l.due[i]==0 && t>=l.next_mate[i] && a.energy[i]>=G.RABBIT_LIFE.breeding_energy]
    nearby=[i for i in available if any(j->hypot(a.x[i]-a.x[j],a.z[i]-a.z[j])<=G.RABBIT_LIFE.mate_radius && H.clear(s.world,(a.x[i],a.z[i]),(a.x[j],a.z[j])),males)]
    push!(rows,(day,alive=length(alive),births=l.births,conceptions=l.conceptions,litters=l.litters,lost_pregnancies=l.lost_pregnancies,pregnant=count(i->s.alive[i]&&l.due[i]>0,eachindex(l.due)),mature_females=length(females),mature_males=length(males),immature=length(alive)-length(mature),eligible_females=length(available),eligible_females_near_male=length(nearby),energy_mean=isempty(alive) ? nothing : mean(a.energy[alive])))
end
write(ARGS[2],JSON3.write(rows))
println("READ ",length(rows)," CHECKPOINTS; final births=",last(rows).births)
