using JSON3,Serialization,Test
root=ARGS[1];output=ARGS[2]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
include("../../src/lw/configured_paths/rabbit_food_pressure_experiment.jl")
Core.eval(H,:(const FOOD_PRESSURE_HOOK=Ref{Any}(nothing)))
source=read(joinpath(root,"source/src/ecology/herbivore/approach.jl"),String)
target="function target!("*split(split(source,"function target!(")[2],"function approach_feedback!")[1]
target=replace(target,"pressure=maximum(get(m.H,o.cell,0.) for o in observations)"=>"pressure=max(maximum(get(m.H,o.cell,0.) for o in observations),FOOD_PRESSURE_HOOK[]===nothing ? 0. : FOOD_PRESSURE_HOOK[](i))")
target=replace(target,"    chosen=if pressure==0"=>"    pressure=FOOD_GATE_HOOK[]===nothing ? pressure : FOOD_GATE_HOOK[](i,pressure)
    chosen=if pressure==0")
Core.eval(H,:(const FOOD_GATE_HOOK=Ref{Any}(nothing)))
include_string(H,target)
function trial(enabled;thresholded=false,gate_settings=RABBIT_FOOD_PRESSURE_GATE)
 saved=deserialize(joinpath(root,"checkpoints/day-014.jls"));s=saved.world;c=saved.cohort;a=s.animals
 memory=RabbitFoodPressure();gate=RabbitFoodPressureGate();samples=Any[];before=a.consumed[16];blocked=a.blocked[16]
 H.FOOD_PRESSURE_HOOK[]=enabled ? (i->i==16 ? configured_food_pressure!(memory,a,i,s.ticks) : 0.) : nothing
 H.FOOD_GATE_HOOK[]=thresholded ? ((i,p)->i==16 ? configured_food_pressure_gate!(gate,p,s.ticks;settings=gate_settings) : p) : nothing
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
 (enabled,thresholded,gate=(calls=gate.calls,active_calls=gate.active_calls,records=gate.records),seconds=timing,alive=s.alive[16],energy=a.energy[16],eaten=a.consumed[16]-before,blocked=a.blocked[16]-blocked,peakH=memory.peak,records=memory.records,samples)
end
if abspath(PROGRAM_FILE)==@__FILE__
@testset "pressure gate boundaries" begin
 g=RabbitFoodPressureGate()
 enter=RABBIT_FOOD_PRESSURE_GATE.enter_H;leave=RABBIT_FOOD_PRESSURE_GATE.exit_H;mid=(enter+leave)/2
 for (p,active) in ((0.,false),(enter/1000,false),(prevfloat(enter),false),(enter,true),(mid,true),(leave,false),(mid,false),(enter+1,true),(0.,false))
  @test configured_food_pressure_gate!(g,p,0)==(active ? p : 0.)
  @test g.active==active
 end
 @test configured_food_pressure_gate!(g,.001,0;settings=merge(RABBIT_FOOD_PRESSURE_GATE,(enabled=false,)))==.001
end
baseline=trial(false);treatment=trial(true);thresholded=trial(true;thresholded=true)
# Verify shared approach to the incident, before parent pressure begins.
@test filter(p->p.tick<243748,baseline.samples)==filter(p->p.tick<243748,treatment.samples)
@test filter(p->p.tick<243748,baseline.samples)==filter(p->p.tick<243748,thresholded.samples)
write(output,JSON3.write((;conditions=RABBIT_FOOD_PRESSURE,gate_conditions=RABBIT_FOOD_PRESSURE_GATE,baseline,treatment,thresholded)))
for r in (baseline,treatment,thresholded);println(JSON3.write((enabled=r.enabled,thresholded=r.thresholded,gate=r.gate,seconds=r.seconds,alive=r.alive,energy=r.energy,eaten=r.eaten,blocked=r.blocked,peakH=r.peakH)));end
end
