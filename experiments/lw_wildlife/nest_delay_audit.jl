using Serialization,JSON3,Random
const nest_root="C:/Users/ken_m/Documents/Codex/raptor-foodresolved2336-360d-20261110/run"
include(joinpath(nest_root,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(nest_root,"source/src/lw/configured_paths/raptor_trial.jl"))
rows=Any[]
for day in (1,90,110,217,264,265)
 saved=deserialize(joinpath(nest_root,"checkpoints/day-"*lpad(day,3,'0')*".jls"));s=saved.world;a=s.animals;l=s.life;i=1890;p=(a.x[i],a.z[i]);goal=l.nest[i]
 candidates=G.configured_rabbit_nest_candidates(s,i,s.ticks)
 push!(rows,(day=day,position=p,goal=goal,due=l.due[i],allowed=G.configured_rabbit_nest_allowed(s.world,p),goal_allowed=G.configured_rabbit_nest_allowed(s.world,goal),clear=H.clear(s.world,p,goal),goal_water=H.material(s.world.phase,goal...)==H.WATER,midpoint_water=H.material(s.world.phase,(p[1]+goal[1])/2,(p[2]+goal[2])/2)==H.WATER,distance=hypot(p[1]-goal[1],p[2]-goal[2]),energy=a.energy[i],sleepy=a.sleepy[i],state=a.state[i],override=s.overrides[i],candidates=length(candidates),bounds=(s.world.xmin,s.world.xmax,s.world.zmin,s.world.zmax)))
end
write(joinpath(@__DIR__,"evidence/nest-delay-1890.json"),JSON3.write(rows));println(JSON3.write(rows))

