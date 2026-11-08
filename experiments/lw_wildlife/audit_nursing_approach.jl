# Read-only replay, mother 12, days 63..65. Wrapper preserves the original steering.
using Serialization,JSON3,Test
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function audit()
 saved=deserialize(joinpath(root,"checkpoints/day-062.jls"));s=saved.world;c=saved.cohort
 @assert isempty(c.predators)
 mom=12;kid=913;nest=s.life.nest[kid];rows=Any[];events=Any[];checks=Any[]
 counts=Dict{String,Int}();steer=Ref{Any}(nothing);closest=Ref{Any}(nothing)
 steering=(w,a,i,speed,overrides)->begin
  base=a.heading[i];h=G.configured_rabbit_potential(w,a,i,speed,overrides)
  if i==mom
   p=(a.x[i],a.z[i]);hb=H.configured_boundary_heading(w,p,h)
   steer[]=(base,obstacle=h,boundary=hb,clear=H.clear(w,p,(p[1]+speed*cos(hb),p[2]+speed*sin(hb))))
  end
  h
 end
 for t in s.ticks:(360+65)*17280-1
  a=s.animals;before=(a.x[mom],a.z[mom]);mother_energy_before=a.energy[mom];child_energy_before=a.energy[kid];nursed=s.life.nursed_day[kid];alive=s.alive[kid];steer[]=nothing
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  override=s.overrides[mom];target=a.target[mom];wanted=alive&&s.life.nursed_day[kid]<div(t,17280)
  G.advance!(s,t;steering,grazing_policy=c.rabbit_approach)
  distance=hypot(a.x[mom]-nest[1],a.z[mom]-nest[2]);key="$(wanted)/$(override)/$(H.STATES[a.state[mom]])"
  counts[key]=get(counts,key,0)+1
  row=(tick=t,day=(t+1)/17280-360,position=(a.x[mom],a.z[mom]),distance,energy=a.energy[mom],mother_energy_before,child_energy_before,child_energy_after=a.energy[kid],wanted,override,target,state=H.STATES[a.state[mom]],nursed=s.life.nursed_day[kid],child_alive=s.alive[kid],steering=steer[],before)
  if wanted && (closest[]===nothing || distance<closest[].distance);closest[]=row;end
  t%60==0 && push!(rows,row)
  if nursed!=s.life.nursed_day[kid] || alive!=s.alive[kid];push!(events,row);end
  if (t+1)%17280==0
   day=div(t+1,17280)-360;expected=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world
   animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds)
   same=s.alive==expected.alive && a.x==expected.animals.x && a.z==expected.animals.z && a.energy==expected.animals.energy && s.world.grass==expected.world.grass
   @test same;push!(checks,(day=day,same=same));println("MATCH ",day);flush(stdout)
  end
 end
 nearby=[(x=o.x,z=o.z,radius=o.radius) for o in s.world.obstacles if hypot(o.x-nest[1],o.z-nest[2])<8]
 write(ARGS[2],JSON3.write((nest,nearby,closest=closest[],events,counts,checks,rows)))
end
audit()
