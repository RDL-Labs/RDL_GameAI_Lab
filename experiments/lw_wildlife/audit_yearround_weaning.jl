using Serialization,JSON3
const root=ARGS[1]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function main()
 rows=Any[]
 for day in 55:67
  s=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world
  ids=findall(s.alive);dep=count(i->G.dependent(s.life,i,s.ticks),ids)
  recent=count(i->28<=(s.ticks-s.life.born[i])/17280<35,ids)
  push!(rows,(day,alive=length(ids),dependent=dep,independent=length(ids)-dep,recent_weaned=recent,grass=sum(s.world.grass),grown=s.world.grown,eaten=s.world.eaten))
 end
 write(ARGS[2],JSON3.write(rows));println(JSON3.write(rows))
end
main()
