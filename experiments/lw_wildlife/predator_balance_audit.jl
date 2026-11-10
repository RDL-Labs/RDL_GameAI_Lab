using Serialization,JSON3,Random
const audit_run="C:/Users/ken_m/Documents/Codex/raptor-open-ended-20261110/run"
include(joinpath(audit_run,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(audit_run,"source/src/lw/configured_paths/raptor_trial.jl"))
function audit()
 saved=deserialize(joinpath(audit_run,"checkpoints/day-100.jls"));s=saved.world;c=saved.cohort;b=saved.raptor;p=only(c.predators)
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 residual()=BigFloat(PREDATOR_ANIMAL_TRIAL.initial_food)+BigFloat(p.eaten)-BigFloat(p.food)-BigFloat(p.spent)
 initial=residual();peak=BigFloat(0);changes=BigFloat(0);ticks=0
 for t in s.ticks:551*17280-1
  if t%17280==0
   configured_raptor_population!(b,count(s.alive),t)
  end
  before=residual()
  animal_trial_prepare!(s,c.predators,t;raptor=b,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
  configured_raptor_step!(b,s,c.predators,t)
  delta=residual()-before;peak=max(peak,abs(delta));changes+=delta;ticks+=1
 end
 supplied=900+p.eaten;accounted=p.food+p.spent
 result=(day=551,ticks,initial_residual=Float64(initial),final_residual=Float64(residual()),change=Float64(changes),peak_single_tick_residual_change=Float64(peak),food=p.food,eaten=p.eaten,spent=p.spent,alive=p.alive,old_check=isapprox(supplied,accounted;atol=1e-7,rtol=1e-10),relative_error=Float64(abs(residual())/max(supplied,accounted)),captures=p.visual.body.captures)
 @assert peak<1e-9
 Base.include(G,joinpath(@__DIR__,"../../src/ecology/lw_grazing/balance.jl"))
 report_source=read(joinpath(@__DIR__,"../../src/lw/configured_paths/predator_animal_trial.jl"),String)
 Base.include_string(Main,"function trial_predator_report(p)"*split(report_source,"function trial_predator_report(p)";limit=2)[2])
 report=Base.invokelatest(trial_predator_report,p)
 @assert report.balance_diagnostic.status=="ok"
 @assert report.balance_diagnostic.numerical_adjustment_total==report.balance_diagnostic.residual
 @assert report.balance_diagnostic.adjusted_residual==0.
 @assert report.food==p.food && report.eaten==p.eaten && report.spent==p.spent
 for (supplied,accounted) in ((100.,101.),(NaN,100.),(100.,Inf))
  rejected=false
  try;G.balance_diagnostic("test",supplied,accounted);catch;rejected=true;end
  @assert rejected
 end
 result=merge(result,(new_diagnostic=report.balance_diagnostic,large_and_nonfinite_rejected=true,))
 write(joinpath(@__DIR__,"evidence/predator-balance-day551.json"),JSON3.write(result));println(JSON3.write(result))
end
audit()


