using Serialization,JSON3,Random
const trap_root="C:/Users/ken_m/Documents/Codex/raptor-west2306-360d-20261110/run"
include(joinpath(trap_root,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(trap_root,"source/src/lw/configured_paths/raptor_trial.jl"))
@eval H begin
 const trap_trace=Any[]
 const trap_counts=Dict{Int,Dict{String,Int}}()
 function trap_count(i,key,condition=true)
  i in 2162:2166 && condition || return
  counts=get!(()->Dict{String,Int}(),trap_counts,i);counts[key]=get(counts,key,0)+1
 end
end
source=read(joinpath(trap_root,"source/src/ecology/motion-vision-cpu/Herbivores.jl"),String)
step_source="function step!("*split(split(source,"function step!(";limit=2)[2],"function simulate(";limit=2)[1]
step_source=replace(step_source,"if growth!==nothing && hypot(a.x[i]-growth.nest[1],a.z[i]-growth.nest[2])+speed>growth.radius"=>"trap_count(i,\"movement\"); if growth!==nothing && a.target[i]!=0; target_position=center(w,a.target[i]);trap_count(i,\"target_outside_radius\",hypot(target_position[1]-growth.nest[1],target_position[2]-growth.nest[2])>growth.radius);end\n            if growth!==nothing && hypot(a.x[i]-growth.nest[1],a.z[i]-growth.nest[2])+speed>growth.radius\n                trap_count(i,\"turned_to_nest\")")
step_source=replace(step_source,"if !allowed(q) || !rabbit_land_step!(w,a,i,q)"=>"trap_count(i,\"disallowed\",!allowed(q));trap_count(i,\"geometry_blocked\",!clear(w,p,q));\n            if !allowed(q) || !rabbit_land_step!(w,a,i,q)")
step_source=replace(step_source,"speed=state==FLEE ? .6 : .2"=>"if i==2162 && length(trap_trace)<60;push!(trap_trace,(tick=t,position=(a.x[i],a.z[i]),cell=a.current_cell[i],previous=a.previous_cell[i],target=a.target[i],target_position=a.target[i]==0 ? nothing : center(w,a.target[i])));end\n            speed=state==FLEE ? .6 : .2")
Base.include_string(H,step_source)
function audit()
 saved=deserialize(joinpath(trap_root,"checkpoints/day-079.jls"));s=saved.world;c=saved.cohort;b=saved.raptor
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 initial=[(id=i,nest=s.life.nest[i],position=(s.animals.x[i],s.animals.z[i]),growth=G.configured_rabbit_growth(s,i,s.ticks)) for i in 2162:2166]
 ranges=Dict(i=>[Inf,-Inf,Inf,-Inf] for i in 2162:2166)
 for t in s.ticks:2386*17280-1
  animal_trial_prepare!(s,c.predators,t;raptor=b,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  configured_raptor_step!(b,s,c.predators,t)
  for i in 2162:2166
   r=ranges[i];x=s.animals.x[i];z=s.animals.z[i];r[1]=min(r[1],x);r[2]=max(r[2],x);r[3]=min(r[3],z);r[4]=max(r[4],z)
  end
 end
 expected=deserialize(joinpath(trap_root,"checkpoints/day-080.jls"))
 matched=all(i->s.animals.x[i]==expected.world.animals.x[i] && s.animals.z[i]==expected.world.animals.z[i] && s.animals.energy[i]==expected.world.animals.energy[i],2162:2166)
 @assert matched
 result=(matched,initial,ranges,counts=H.trap_counts,trace=H.trap_trace)
 write(joinpath(@__DIR__,"evidence/juvenile-trap-day2386.json"),JSON3.write(result));println(JSON3.write(result))
end
audit()

