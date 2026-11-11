using Serialization,JSON3,Random,Test
include(joinpath(@__DIR__,"predator_generations.jl"))
include(joinpath(@__DIR__,"../../src/lw/configured_paths/raptor_trial.jl"))
const root="C:/Users/ken_m/Documents/Codex/raptor-foodresolved2336-360d-20261110/run"
saved=deserialize(joinpath(root,"checkpoints/day-001.jls"));s=saved.world;i=1890
s.life.due[i]=s.ticks+2*17280
origin=(s.animals.x[i],s.animals.z[i]);start_tick=s.ticks
@test G.configured_maternal_boundary_goal(s,i,s.ticks)!==nothing
s.overrides[i]=H.FLEE;G.configured_rabbit_nest_preparation!(s,s.ticks)
@test s.overrides[i]==H.FLEE
s.overrides[i]=0
maximum_step=0.
for tick in start_tick:start_tick+99
 previous=(s.animals.x[i],s.animals.z[i])
 G.prepare!(s,[(1000.,1000.) for _ in s.previous_humans],tick)
 G.advance!(s,tick;grazing_policy=saved.cohort.rabbit_approach)
 global maximum_step=max(maximum_step,hypot(s.animals.x[i]-previous[1],s.animals.z[i]-previous[2]))
end
@test maximum_step<=.2+1e-9
@test G.configured_maternal_boundary_goal(s,i,s.ticks)===nothing
@test G.configured_rabbit_nest_allowed(s.world,(s.animals.x[i],s.animals.z[i]))
@test s.life.due[i]==start_tick+2*17280
result=(mother=i,origin=origin,position=(s.animals.x[i],s.animals.z[i]),ticks=100,max_step=maximum_step,energy=s.animals.energy[i])
write(joinpath(@__DIR__,"evidence/maternal-boundary-1890.json"),JSON3.write(result));println(JSON3.write(result))
