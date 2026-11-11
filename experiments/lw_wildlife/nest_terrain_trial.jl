using Serialization,JSON3,Random,Test
const trial_root="C:/Users/ken_m/Documents/Codex/raptor-foodresolved2336-360d-20261110/run"
include(joinpath(@__DIR__,"predator_generations.jl"))
include(joinpath(@__DIR__,"../../src/lw/configured_paths/raptor_trial.jl"))
function trial()
 saved=deserialize(joinpath(trial_root,"checkpoints/day-001.jls"));s=saved.world;c=saved.cohort;b=saved.raptor;i=1890
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 old=s.life.nest[i];origin=(s.animals.x[i],s.animals.z[i]);births=s.life.births
 @test H.clear(s.world,origin,old)
 rows=Any[]
 for t in s.ticks:s.ticks+2*17280-1
  animal_trial_prepare!(s,c.predators,t;raptor=b,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  if isempty(rows)
   @test s.life.nest[i]==old
   @test H.clear(s.world,origin,s.life.nest[i])
   push!(rows,(old=old,new=s.life.nest[i],position=origin))
  end
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  configured_raptor_step!(b,s,c.predators,t)
 end
 result=(selection=rows,position=(s.animals.x[i],s.animals.z[i]),due=s.life.due[i],alive=s.alive[i],energy=s.animals.energy[i],lost_pregnancies=s.life.lost_pregnancies,starvation=s.starvation_records[end-min(2,length(s.starvation_records)-1):end],children=[j for j in eachindex(s.alive) if s.alive[j] && s.life.mother[j]==i],captures=[e for p in c.predators for e in p.visual.events if e.kind=="capture" && e.id==i],births_added=s.life.births-births)
 write(joinpath(@__DIR__,"evidence/nest-terrain-1890.json"),JSON3.write(result));println(JSON3.write(result))
end
trial()




