using Serialization,JSON3
include(joinpath(ARGS[1],"source/experiments/lw_wildlife/predator_generations.jl"))
rows=Any[]
for day in (1,2,4,49,50,53,60,82,127,130)
 root=day<=90 ? ARGS[1] : ARGS[2];d=day<=90 ? day : day-90
 a=deserialize(joinpath(root,"checkpoints/day-"*lpad(d-1,3,'0')*".jls"));b=deserialize(joinpath(root,"checkpoints/day-"*lpad(d,3,'0')*".jls"))
 captured=Set(e.id for p in b.cohort.predators for e in p.visual.events if e.kind=="capture" && (day-1)*17280<=e.tick<day*17280)
 for i in eachindex(a.world.alive)
  a.world.alive[i] && !b.world.alive[i] && !(i in captured) || continue
  s=b.world;l=s.life;m=l.mother[i]
  push!(rows,(day,id=i,age_day_end=(day*17280-l.born[i])/17280,energy=s.animals.energy[i],mother=m,mother_alive_end=m>0 ? s.alive[m] : nothing,mother_energy_end=m>0 ? s.animals.energy[m] : nothing,mother_distance_end=m>0 ? hypot(s.animals.x[i]-s.animals.x[m],s.animals.z[i]-s.animals.z[m]) : nothing))
 end
end
write(ARGS[3],JSON3.write(rows));println(JSON3.write(rows))
