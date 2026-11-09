using JSON3,Serialization,Test
root=ARGS[1];output=ARGS[2]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
include("../../src/lw/configured_paths/rabbit_local_rho_experiment.jl")
# Reuse exact frozen predator update; add only an optional rabbit steering hook.
frozen=read(joinpath(root,"source/experiments/lw_wildlife/animals_only.jl"),String)
body=split(split(frozen,"function animal_trial_advance!")[2],"function animal_trial_step!")[1]
body=replace(body,"grazing_policy=G.H.StateMachinePolicy())"=>"grazing_policy=G.H.StateMachinePolicy(),rho_steering=nothing)")
body=replace(body,"G.advance!(s,t;steering=rabbit_steering,grazing_policy)"=>"G.advance!(s,t;steering=rho_steering===nothing ? rabbit_steering : rho_steering,grazing_policy)")
include_string(Main,"function rho_trial_advance!"*body)
function trial(enabled)
 saved=deserialize(joinpath(root,"checkpoints/day-071.jls"));s=saved.world;c=saved.cohort;a=s.animals
 memory=RabbitLocalRho();samples=Any[];eaten_before=a.consumed[71];blocked_before=a.blocked[71]
 H.enable_rabbit_neighbor_batch!(s.world;gpu=true,automatic=true)
 steering=(w,a,i,speed,overrides)->begin
   base=G.configured_rabbit_potential(w,a,i,speed,overrides)
   # Both runs share the exact state up to the observed trapping episode.
   enabled && i==71 && s.ticks>=1234059 ? configured_rabbit_local_rho!(memory,w,a,i,s.ticks,base;geometry=H) : base
 end
 timing=@elapsed for t in s.ticks:72*17280-1
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  rho_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach,rho_steering=enabled ? steering : nothing)
  if t>=1233900 && s.alive[71]
   push!(samples,(tick=t,position=(a.x[71],a.z[71]),energy=a.energy[71],state=H.STATES[a.state[71]],H=memory.H,consumed=a.consumed[71]-eaten_before))
  end
 end
 animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
 if !enabled
  expected=deserialize(joinpath(root,"checkpoints/day-072.jls")).world
  @test s.alive==expected.alive && a.x==expected.animals.x && a.energy==expected.animals.energy && s.world.grass==expected.world.grass
 end
 @test isapprox(s.world.initial+s.world.grown,sum(s.world.grass)+s.world.eaten;rtol=1e-8)
 @test all(p->H.clear(s.world,p.position,p.position),samples)
 (enabled,seconds=timing,alive=s.alive[71],energy=a.energy[71],position=(a.x[71],a.z[71]),eaten=a.consumed[71]-eaten_before,blocked=a.blocked[71]-blocked_before,queries=memory.queries,records=memory.records,samples,children=[(id=j,alive=s.alive[j],energy=a.energy[j],nursed=s.life.nursed_day[j]) for j in 153:156])
end
baseline=trial(false);treatment=trial(true)
@test baseline.samples[1:findlast(p->p.tick<1234059,baseline.samples)]==treatment.samples[1:findlast(p->p.tick<1234059,treatment.samples)]
write(output,JSON3.write((;conditions=RABBIT_LOCAL_RHO,baseline,treatment)))
for r in (baseline,treatment);println(JSON3.write((enabled=r.enabled,seconds=r.seconds,alive=r.alive,energy=r.energy,eaten=r.eaten,blocked=r.blocked,queries=r.queries,events=length(r.records),children=r.children)));end
