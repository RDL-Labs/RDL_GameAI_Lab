# Read-only diagnostic replay: RUN_DIRECTORY OUTPUT_JSON.
# Frozen modules; replay selected checkpoint days. Optional START_DAY END_DAY.
# Measurements never invoke mutating observation or consume random numbers.
using JSON3,Serialization,Statistics,Test
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function audit()
 replay_start=length(ARGS)>=3 ? parse(Int,ARGS[3]) : 63; replay_end=length(ARGS)>=4 ? parse(Int,ARGS[4]) : 67
 saved=deserialize(joinpath(root,"checkpoints/day-"*lpad(replay_start,3,'0')*".jls"));s=saved.world;c=saved.cohort
 replay_origin=div(s.ticks,17280)-replay_start
 H.enable_rabbit_neighbor_batch!(s.world;gpu=true,automatic=true)
 baseline_consumed=copy(s.animals.consumed);last_milk=fill(-1,length(s.alive))
 deaths=Any[];samples=Any[];checks=Any[]
 for t in s.ticks:(replay_origin+replay_end)*17280-1
  oldalive=copy(s.alive);before_energy=copy(s.animals.energy)
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  length(last_milk)<length(s.alive) && append!(last_milk,fill(-1,length(s.alive)-length(last_milk)))
  for i in eachindex(oldalive)
   G.dependent(s.life,i,t) && s.animals.energy[i]>before_energy[i] && (last_milk[i]=t)
  end
  for i in eachindex(oldalive)
   oldalive[i]&&!s.alive[i] || continue
   a=s.animals;w=s.world;k=H.cell(w,a.x[i],a.z[i]);mother=s.life.mother[i]
   available(j)=min(w.capacity[j],w.grass[j]+w.capacity[j]*max(0,t-w.updated[j])/(2*17280))
   ix=mod(k-1,w.nx)+1;iz=div(k-1,w.nx)+1
   neighbors=Int[]
   for (dx,dz) in H.OFFSETS
    jx=ix+dx;jz=iz+dz
    1<=jx<=w.nx && 1<=jz<=w.nz || continue
    j=jx+(jz-1)*w.nx
    w.walkable[j] && H.clear(w,(a.x[i],a.z[i]),H.center(w,j)) && push!(neighbors,j)
   end
   push!(deaths,(eaten_since_start=a.consumed[i]-(i<=length(baseline_consumed) ? baseline_consumed[i] : 0.),last_milk_tick=last_milk[i],mother_gut=mother>0 ? a.gut[mother] : nothing,mother_state=mother>0 ? H.STATES[a.state[mother]] : nothing,mother_swimming=mother>0 ? haskey(c.rabbit_approach.trips,mother) : false,tick=t,day=cld(t+1,17280)-replay_origin,id=i,west=a.x[i]<12+5sin((a.z[i]-6)/22+w.phase),energy=a.energy[i],last_nursed=s.life.nursed_day[i],mother_energy=mother>0 ? a.energy[mother] : nothing,mother_distance=mother>0 ? hypot(a.x[i]-a.x[mother],a.z[i]-a.z[mother]) : nothing,eaten_total=a.consumed[i],travel_total=a.distance[i],age=(t-s.life.born[i])/17280,state=H.STATES[a.state[i]],mother,mother_alive=mother>0 ? s.alive[mother] : nothing,position=(a.x[i],a.z[i]),gut=a.gut[i],cell=k,grass=available(k),capacity=w.capacity[k],nearby_max=isempty(neighbors) ? 0. : maximum(available(j) for j in neighbors),demand=s.demand[k],allocation_ratio=s.ratio[k]))
  end
  if (t+1)%1728==0
   a=s.animals;ids=findall(s.alive);ind=[i for i in ids if !G.dependent(s.life,i,t)]
   push!(samples,(tick=t+1,day=(t+1)/17280-replay_origin,alive=length(ids),energy_mean=mean(a.energy[ind]),gut_mean=mean(a.gut[ind]),hungry=count(i->a.energy[i]<30,ind),search=count(i->a.state[i]==H.SEARCH,ind)))
  end
  if (t+1)%17280==0
   day=div(t+1,17280)-replay_origin;expected=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls"));a=s.animals;b=expected.world.animals
   # Original runner snapshots materialize all grass at each day boundary.
   animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
   same=s.alive==expected.world.alive && a.x==b.x && a.z==b.z && a.energy==b.energy && a.consumed==b.consumed && a.counts==b.counts && s.world.grass==expected.world.world.grass
   @test same
   regions=Any[]
   for westside in (true,false)
    w=s.world;west(x,z)=x<12+5sin((z-6)/22+w.phase)
    ids=[i for i in eachindex(s.alive) if s.alive[i] && west(a.x[i],a.z[i])==westside]
    cells=[k for k in eachindex(w.grass) if west(H.center(w,k)...)==westside]
    push!(regions,(west=westside,alive=length(ids),grass=sum(w.grass[cells]),dependent=count(i->G.dependent(s.life,i,t),ids),energy=isempty(ids) ? 0. : mean(a.energy[ids])))
   end
   push!(checks,(day,same,regions));println("REPLAY ",day," deaths=",length(deaths));flush(stdout)
  end
 end
 H.disable_rabbit_neighbor_gpu!()
 write(ARGS[2],JSON3.write((deaths=deaths,samples=samples,checks=checks)))
end
audit()

