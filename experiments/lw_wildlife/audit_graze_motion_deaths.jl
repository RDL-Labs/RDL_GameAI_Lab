using JSON3,Serialization
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function audit()
 rows=Any[];history=Any[]
 final=deserialize(joinpath(root,"checkpoints/day-090.jls"))
 captures=Dict(e.id=>e.tick for p in final.cohort.predators for e in p.visual.events if e.kind=="capture")
 for day in (2,6,22,46)
  pre=deserialize(joinpath(root,"checkpoints/day-"*lpad(day-1,3,'0')*".jls")).world
  s=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world;a=s.animals
  for i in eachindex(pre.alive)
   pre.alive[i]&&!s.alive[i]&&!haskey(captures,i)||continue
   m=s.life.mother[i];k=H.cell(s.world,a.x[i],a.z[i])
   push!(rows,(day,id=i,age_start=(pre.ticks-s.life.born[i])/17280,mother=m,mother_alive=m>0 ? s.alive[m] : false,mother_capture=get(captures,m,nothing),start_energy=pre.animals.energy[i],end_energy=a.energy[i],last_nursed=s.life.nursed_day[i],position=(a.x[i],a.z[i]),short=s.world.layers.short[k],capacity=s.world.capacity[k],states=a.counts[i,:]-pre.animals.counts[i,:]))
  end
 end
 mothers=unique(r.mother for r in rows)
 for day in 0:46
  s=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world;a=s.animals
  for m in mothers
   children=[i for i in eachindex(s.alive) if s.life.mother[i]==m && s.alive[i] && G.dependent(s.life,i,s.ticks)]
   isempty(children)&&continue
   push!(history,(day,mother=m,alive=s.alive[m],energy=a.energy[m],position=(a.x[m],a.z[m]),children=[(id=i,energy=a.energy[i],nursed=s.life.nursed_day[i],distance=hypot(a.x[i]-a.x[m],a.z[i]-a.z[m])) for i in children]))
  end
 end
 write(ARGS[2],JSON3.write((;rows,history)));println(JSON3.write(rows))
end
audit()
