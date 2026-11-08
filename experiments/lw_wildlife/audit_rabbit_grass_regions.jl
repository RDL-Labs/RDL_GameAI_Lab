# Read-only east/west census: RUN_DIRECTORY OUTPUT_JSON, frozen modules.
using JSON3,Serialization,Statistics
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
rows=Any[]
for day in [120,140,148,149,150,152,153,300]
 s=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world;w=s.world;a=s.animals
 west(x,z)=x<12+5sin((z-6)/22+w.phase)
 for side in (true,false)
  ids=[i for i in eachindex(s.alive) if s.alive[i]&&west(a.x[i],a.z[i])==side]
  cells=[k for k in eachindex(w.grass) if west(H.center(w,k)...)==side]
  ind=[i for i in ids if !G.dependent(s.life,i,day*17280)]
  push!(rows,(day,side=side ? "west" : "east",alive=length(ids),independent=length(ind),energy_mean=mean(a.energy[ind]),energy_min=minimum(a.energy[ind]),gut_mean=mean(a.gut[ind]),grass=sum(w.grass[cells]),capacity=sum(w.capacity[cells]),local_low=count(i->w.grass[H.cell(w,a.x[i],a.z[i])]<.005,ind)))
 end
end
write(ARGS[2],JSON3.write(rows));foreach(x->println(JSON3.write(x)),rows)
