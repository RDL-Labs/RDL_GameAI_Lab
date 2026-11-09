using JSON3,Serialization,Test
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
# Frozen checkpoint types are unchanged; replay-only stores supply the new fields.
Base.include(G,joinpath(@__DIR__,"../../src/lw/configured_paths/wildlife_reproduction.jl"))
Core.eval(G,quote
 const REPLAY_PENDING=IdDict{Any,Set{Int}}()
 const REPLAY_TARGETS=IdDict{Any,Dict{Int,Tuple{Float64,Float64}}}()
 configured_nursing_pending(life)=get!(()->Set{Int}(),REPLAY_PENDING,life)
 configured_nursing_targets(life)=get!(()->Dict{Int,Tuple{Float64,Float64}}(),REPLAY_TARGETS,life)
end)
reproduction_source=read(joinpath(@__DIR__,"../../src/ecology/lw_grazing/reproduction.jl"),String)
nurse_source="function rabbit_nurse!("*split(split(reproduction_source,"function rabbit_nurse!(")[2],"function rabbit_advance!")[1]
include_string(G,nurse_source)
advance_source=read(joinpath(@__DIR__,"../../src/ecology/lw_grazing/LWGrazing.jl"),String)
advance_source="function advance!("*split(split(advance_source,"function advance!(")[2],"include(\"balance.jl\")")[1]
include_string(G,advance_source)
function audit()
 results=Any[]
 for (day,m,child) in ((32,6,107),(42,3,117))
  saved=deserialize(joinpath(root,"checkpoints/day-"*lpad(day-1,3,'0')*".jls"));s=saved.world;c=saved.cohort;a=s.animals
  samples=Any[];stats=Dict{String,Int}();min_distance=Inf
  H.enable_rabbit_neighbor_batch!(s.world;gpu=true,automatic=true)
  for t in s.ticks:day*17280-1
   animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
   if s.alive[child]
    dist=hypot(a.x[m]-a.x[child],a.z[m]-a.z[child]);min_distance=min(min_distance,dist)
    key="override_"*string(s.overrides[m]);stats[key]=get(stats,key,0)+1
    if t%60==0 || a.energy[child]<.01
     push!(samples,(tick=t,energy=a.energy[m],child_energy=a.energy[child],distance=dist,override=s.overrides[m],state=a.state[m],target=a.target[m],position=(a.x[m],a.z[m]),nest=s.life.nest[child],child_position=(a.x[child],a.z[child]),child_state=a.state[child],child_gut=a.gut[child],nursed=s.life.nursed_day[child],blocked=a.blocked[m]))
    end
   end
   animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  end
  animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
  expected=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world
  @test isapprox(s.world.initial+s.world.grown,sum(s.world.grass)+s.world.eaten;rtol=1e-8)
  println(JSON3.write((day,m,child,alive=s.alive[child],energy=a.energy[child],mother_energy=a.energy[m],min_distance,blocked=a.blocked[m],pending=collect(G.configured_nursing_pending(s.life)))))
  push!(results,(;day,m,child,stats,min_distance,samples))
 end
 write(ARGS[2],JSON3.write(results))
end
audit()

