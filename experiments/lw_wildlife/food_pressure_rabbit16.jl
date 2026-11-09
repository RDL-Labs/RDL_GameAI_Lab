using JSON3,Serialization,Test
root=ARGS[1];output=ARGS[2]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
include("../../src/lw/configured_paths/rabbit_food_pressure_experiment.jl")
Core.eval(H,:(const FOOD_PRESSURE_HOOK=Ref{Any}(nothing)))
source=read(joinpath(root,"source/src/ecology/herbivore/approach.jl"),String)
target="function target!("*split(split(source,"function target!(")[2],"function approach_feedback!")[1]
target=replace(target,"pressure=maximum(get(m.H,o.cell,0.) for o in observations)"=>"pressure=max(maximum(get(m.H,o.cell,0.) for o in observations),FOOD_PRESSURE_HOOK[]===nothing ? 0. : FOOD_PRESSURE_HOOK[](i))")
include_string(H,target)
function trial(enabled)
 saved=deserialize(joinpath(root,"checkpoints/day-014.jls"));s=saved.world;c=saved.cohort;a=s.animals
 memory=RabbitFoodPressure();samples=Any[];before=a.consumed[16];blocked=a.blocked[16]
 H.FOOD_PRESSURE_HOOK[]=enabled ? (i->i==16 ? configured_food_pressure!(memory,a,i,s.ticks) : 0.) : nothing
 H.enable_rabbit_neighbor_batch!(s.world;gpu=true,automatic=true)
 timing=@elapsed for t in s.ticks:15*17280-1
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  if s.alive[16]
   push!(samples,(tick=t,position=(a.x[16],a.z[16]),energy=a.energy[16],state=H.STATES[a.state[16]],H=memory.H,consumed=a.consumed[16]-before,cell=H.cell(s.world,a.x[16],a.z[16])))
  end
 end
 animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
 if !enabled
  expected=deserialize(joinpath(root,"checkpoints/day-015.jls")).world
  @test s.alive==expected.alive && a.x==expected.animals.x && a.energy==expected.animals.energy && s.world.grass==expected.world.grass
 end
 @test isapprox(s.world.initial+s.world.grown,sum(s.world.grass)+s.world.eaten;rtol=1e-8)
 @test all(p->H.clear(s.world,p.position,p.position),samples)
 (enabled,seconds=timing,alive=s.alive[16],energy=a.energy[16],eaten=a.consumed[16]-before,blocked=a.blocked[16]-blocked,peakH=memory.peak,records=memory.records,samples)
end
baseline=trial(false);treatment=trial(true)
# Verify shared approach to the incident, before parent pressure begins.
@test filter(p->p.tick<243748,baseline.samples)==filter(p->p.tick<243748,treatment.samples)
write(output,JSON3.write((;conditions=RABBIT_FOOD_PRESSURE,baseline,treatment)))
for r in (baseline,treatment);println(JSON3.write((enabled=r.enabled,seconds=r.seconds,alive=r.alive,energy=r.energy,eaten=r.eaten,blocked=r.blocked,peakH=r.peakH)));end
