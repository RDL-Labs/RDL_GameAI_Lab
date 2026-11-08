# Read-only diagnostic replay: RUN_DIRECTORY OUTPUT_JSON.
# Frozen modules and day-148 state; verifies against original days 149..152.
# Measurements never invoke mutating observation or consume random numbers.
using JSON3,Serialization,Statistics,Test
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function audit()
 saved=deserialize(joinpath(root,"checkpoints/day-148.jls"));s=saved.world;c=saved.cohort
 deaths=Any[];samples=Any[];checks=Any[]
 for t in 148*17280:152*17280-1
  oldalive=copy(s.alive)
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
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
   push!(deaths,(tick=t,day=cld(t+1,17280),id=i,age=(t-s.life.born[i])/17280,state=H.STATES[a.state[i]],mother,mother_alive=mother>0 ? s.alive[mother] : nothing,position=(a.x[i],a.z[i]),gut=a.gut[i],cell=k,grass=available(k),capacity=w.capacity[k],nearby_max=isempty(neighbors) ? 0. : maximum(available(j) for j in neighbors),demand=s.demand[k],allocation_ratio=s.ratio[k]))
  end
  if (t+1)%1728==0
   a=s.animals;ids=findall(s.alive);ind=[i for i in ids if !G.dependent(s.life,i,t)]
   push!(samples,(tick=t+1,day=(t+1)/17280,alive=length(ids),energy_mean=mean(a.energy[ind]),gut_mean=mean(a.gut[ind]),hungry=count(i->a.energy[i]<30,ind),search=count(i->a.state[i]==H.SEARCH,ind)))
  end
  if (t+1)%17280==0
   day=div(t+1,17280);expected=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls"));a=s.animals;b=expected.world.animals
   # Original runner snapshots materialize all grass at each day boundary.
   animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds)
   same=s.alive==expected.world.alive && a.x==b.x && a.z==b.z && a.energy==b.energy && a.consumed==b.consumed && a.counts==b.counts && s.world.grass==expected.world.world.grass
   @test same
   push!(checks,(day,same));println("REPLAY ",day," deaths=",length(deaths));flush(stdout)
  end
 end
 write(ARGS[2],JSON3.write((deaths,samples,checks)))
end
audit()
