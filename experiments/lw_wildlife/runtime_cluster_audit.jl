using Serialization,JSON3,Random
const cluster_run="C:/Users/ken_m/Documents/Codex/raptor-west2306-360d-20261110/run"
include(joinpath(cluster_run,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(cluster_run,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 load_day(d)=deserialize(joinpath(cluster_run,"checkpoints/day-"*lpad(d-2306,3,'0')*".jls"))
 rows=Any[];prior=load_day(2379)
 for day in 2380:2388
  saved=load_day(day);s=saved.world;a=s.animals;old=prior.world.animals
  policy=H.rabbit_approach_base(saved.cohort.rabbit_approach)
  for i in eachindex(s.alive)
   i<=length(old.x) || continue
   search=a.counts[i,H.SEARCH]-old.counts[i,H.SEARCH]
   search>100 || i in (2156,2162,2167) || continue
   k=H.cell(s.world,a.x[i],a.z[i]);H.grass!(s.world,k,s.ticks)
   nearby=count(j->s.alive[j] && hypot(a.x[j]-a.x[i],a.z[j]-a.z[i])<=3,eachindex(s.alive))
   m=get(policy.actors,i,nothing)
   push!(rows,(day,id=i,mother=s.life.mother[i],age=(s.ticks-s.life.born[i])/17280,alive=s.alive[i],search,graze=a.counts[i,H.GRAZE]-old.counts[i,H.GRAZE],flee=a.counts[i,H.FLEE]-old.counts[i,H.FLEE],intake=a.consumed[i]-old.consumed[i],distance=a.distance[i]-old.distance[i],energy=a.energy[i],position=(a.x[i],a.z[i]),previous_position=(old.x[i],old.z[i]),nearby,cell=k,short=s.world.layers.short[k],long=s.world.layers.long[k],capacity=s.world.capacity[k],H=m===nothing ? nothing : m.food_pressure.H))
  end
  prior=saved
 end
 write(joinpath(@__DIR__,"evidence/runtime-cluster-2380-2388.json"),JSON3.write(rows))
 for day in 2380:2388
  group=filter(r->r.day==day,rows);sort!(group;by=r->r.search,rev=true)
  println(JSON3.write((day,total_search=sum(r.search for r in group;init=0),actors=length(group),top=group[1:min(8,end)])))
 end
end
audit()

