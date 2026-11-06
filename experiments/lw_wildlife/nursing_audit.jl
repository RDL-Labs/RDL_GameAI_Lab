using JSON3, Serialization
length(ARGS)==2 || error("BASE_RUN OUTPUT")
const base=abspath(ARGS[1]);const output=abspath(ARGS[2])
ispath(output) && error("fresh audit output required");mkpath(output)
include(joinpath(base,"source/ecology/lw_grazing/LWGrazing.jl"))
const G=LWGrazing
function main()
 input=JSON3.read(read(joinpath(base,"input.json"),String))
 scene=merge((;pairs(input.scene)...),(wildlife=(enabled=true,count=30,seed=20261028,reproduction=true,grass_scale=1.),))
 s=G.build(scene,input.clock);humans=[(Float64(p[1]),Float64(p[2])) for p in scene.positions]
 mother=12;events=Any[];daily=Any[];first_block=nothing
 return_ticks=0;blocked_returns=0;fear_ticks=0;low_energy_ticks=0
 for t in 0:90G.RABBIT_LIFE.day_ticks-1
  a=s.animals;life=s.life
  children=[i for i in eachindex(s.alive) if life.mother[i]==mother]
  old_nursed=[life.nursed_day[i] for i in children];old_alive=[s.alive[i] for i in children]
  G.prepare!(s,humans,t)
  needy=[i for i in children if s.alive[i] && G.dependent(life,i,t) && life.nursed_day[i]<div(t,G.RABBIT_LIFE.day_ticks)]
  if !isempty(needy)
   fear_ticks+=Int(s.overrides[mother] in (G.H.FLEE,G.H.ALERT))
   low_energy_ticks+=Int(a.energy[mother]<=G.RABBIT_LIFE.maternal_reserve)
  end
  returning=!isempty(needy) && s.overrides[mother]==G.H.SEARCH
  p=(a.x[mother],a.z[mother]);old_blocked=a.blocked[mother]
  if returning
   return_ticks+=1
   goal=G.H.center(s.world,a.target[mother]);angle=atan(goal[2]-p[2],goal[1]-p[1])
   q=(p[1]+.2cos(angle),p[2]+.2sin(angle))
   if !G.H.clear(s.world,p,q) && first_block===nothing
    nest=life.nest[first(needy)]
    obstacles=[(x=o.x,z=o.z,radius=o.radius) for o in s.world.obstacles if G.H.RDLMigrationProbe.segment_hit(p,q,o,.25)]
    first_block=(tick=t,day=div(t,G.RABBIT_LIFE.day_ticks)+1,position=p,nest=nest,target=goal,
        distance=hypot(p[1]-nest[1],p[2]-nest[2]),next_position=q,obstacles=obstacles,
        target_clear=G.H.clear(s.world,goal,goal),energy=a.energy[mother],children=needy,
        child_energy=a.energy[needy],last_nursed=life.nursed_day[needy],override=s.overrides[mother])
    serialize(joinpath(output,"first-block.jls"),s)
    write(joinpath(output,"first-block.json"),JSON3.write(first_block))
   end
  end
  G.advance!(s,t)
  returning && (blocked_returns+=a.blocked[mother]-old_blocked)
  for (j,i) in enumerate(children)
   if old_nursed[j]!=life.nursed_day[i] || old_alive[j]!=s.alive[i]
    push!(events,(tick=t,day=div(t,G.RABBIT_LIFE.day_ticks)+1,child=i,alive=s.alive[i],nursed=life.nursed_day[i],
        child_energy=a.energy[i],mother_energy=a.energy[mother],mother_position=(a.x[mother],a.z[mother]),nest=life.nest[i]))
   end
  end
  if (t+1)%G.RABBIT_LIFE.day_ticks==0
   report=G.snapshot(s)
   push!(daily,(day=div(t+1,G.RABBIT_LIFE.day_ticks),position=(a.x[mother],a.z[mother]),energy=a.energy[mother],
       blocked=a.blocked[mother],children=[(id=i,alive=s.alive[i],energy=a.energy[i],nursed=life.nursed_day[i]) for i in eachindex(s.alive) if life.mother[i]==mother]))
  end
 end
 actual=G.snapshot(s);expected=JSON3.read(read(joinpath(base,"result.json"),String)).final
 same=actual.alive==expected.alive && actual.reproduction.births==expected.reproduction.births &&
    all(x->x.energy==expected.final[x.id].energy && collect(x.position)==expected.final[x.id].position,actual.final)
 @assert same
 audit=(reproduced_final=true,mother=mother,first_block=first_block,return_ticks=return_ticks,
    blocked_returns=blocked_returns,fear_ticks=fear_ticks,low_energy_ticks=low_energy_ticks,events=events,daily=daily)
 write(joinpath(output,"audit.json"),JSON3.write(audit))
 println(JSON3.write((reproduced_final=same,first_block=first_block,return_ticks=return_ticks,blocked_returns=blocked_returns,
    fear_ticks=fear_ticks,low_energy_ticks=low_energy_ticks,events=events)))
end
main()
