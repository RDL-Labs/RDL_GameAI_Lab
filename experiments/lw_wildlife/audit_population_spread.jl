using Serialization,JSON3,Statistics
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function metrics(s,ids)
 a=s.animals;w=s.world
 isempty(ids)&&return nothing
 bins=Dict{Tuple{Int,Int},Int}()
 for i in ids
  k=(floor(Int,(a.x[i]-w.xmin)/8),floor(Int,(a.z[i]-w.zmin)/8));bins[k]=get(bins,k,0)+1
 end
 mx=mean(a.x[ids]);mz=mean(a.z[ids]);counts=collect(values(bins))
 (n=length(ids),occupied_bins=length(bins),max_bin=maximum(counts),top5_fraction=sum(sort(counts;rev=true)[1:min(5,end)])/length(ids),rms_radius=sqrt(mean((a.x[ids].-mx).^2+(a.z[ids].-mz).^2)),grass_under_mean=mean(w.grass[H.cell(w,a.x[i],a.z[i])] for i in ids),low_grass_fraction=count(i->w.grass[H.cell(w,a.x[i],a.z[i])]<.1,ids)/length(ids))
end
function run()
 rows=Any[];snapshots=Dict{Int,Any}()
 for day in 59:90
  s=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world
  day in (65,67,70,71,75,76,79,80,90) && (snapshots[day]=s)
  a=s.animals;w=s.world;west(x,z)=x<12+5sin((z-6)/22+w.phase)
  regions=Any[]
  for side in (true,false)
   ids=[i for i in eachindex(s.alive) if s.alive[i]&&west(a.x[i],a.z[i])==side]
   independent=[i for i in ids if !G.dependent(s.life,i,s.ticks)]
   cells=[k for k in eachindex(w.grass) if west(H.center(w,k)...)==side]
   push!(regions,(west=side,grass=sum(w.grass[cells]),capacity=sum(w.capacity[cells]),all=metrics(s,ids),independent=metrics(s,independent)))
  end
  push!(rows,(day,alive=count(s.alive),deaths=s.deaths-356,grass=sum(w.grass),regions))
 end
 cohorts=Any[]
 for (lo,hi) in ((65,71),(75,80),(80,90))
  a=snapshots[lo];b=snapshots[hi]
  for side in (true,false)
   ids=[i for i in eachindex(a.alive) if a.alive[i] && (a.animals.x[i]<12+5sin((a.animals.z[i]-6)/22+a.world.phase))==side && !G.dependent(a.life,i,a.ticks)]
   survivors=filter(i->b.alive[i],ids);dead=filter(i->!b.alive[i],ids)
   push!(cohorts,(lo,hi,west=side,survivors_before=metrics(a,survivors),survivors_after=metrics(b,survivors),dead_before=metrics(a,dead),mean_displacement=isempty(survivors) ? nothing : mean(hypot(b.animals.x[i]-a.animals.x[i],b.animals.z[i]-a.animals.z[i]) for i in survivors)))
  end
 end
 write(ARGS[2],JSON3.write((rows,cohorts,bin_width=8,note="Spatial bins are diagnostic only. Independent animals exclude milk-dependent young; cohorts compare identical surviving IDs. Day-end grass is materialized by original runner.")))
end
run()
