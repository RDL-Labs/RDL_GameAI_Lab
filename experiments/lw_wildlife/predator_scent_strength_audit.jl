using JSON3,Serialization,Test
include("predator_generations.jl")
for name in ("predator_crossing_layout","rabbit_diverse_start","rabbit_patchy_grass","rabbit_distributed_layout","predator_population_exchange","raptor_trial")
 include("../../src/lw/configured_paths/"*name*".jl")
end
@testset "shared expansion" begin
 @test relational_expansion_fraction(0.)==0
 @test relational_expansion_fraction(20.)==1
 @test relational_expansion_fraction(5.)<.25
 @test issorted([relational_expansion_fraction(h) for h in 0:20])
 @test relational_expansion_fraction(100.)==1
 for h in (0.,1.,5.,10.,20.,30.), n in (1,3,8,20)
  old=clamp(round(Int,1+(min(n,8)-1)*expm1(3clamp(h/20,0,1))/expm1(3)),1,min(n,8))
  @test H.configured_rabbit_candidate_count(h,n)==old
 end
end
function diagnose_cue(saved,s,p,c,actor,t,obs)
 obs===nothing && return (tick=t,kind="none",signal=0.,freshness=nothing,age_days=nothing,steered=false)
 origin=(p.visual.body.x,p.visual.body.z)
 distance=hypot(obs.target[1]-origin[1],obs.target[2]-origin[2])
 source=hasproperty(obs,:source) ? string(obs.source) : "body"
 freshness=nothing;age_days=nothing;amount=nothing
 if source=="body"
  key=prey_scent_cell(obs.target...)
  mark=get(c.prey_scents.marks,key,nothing)
  if mark!==nothing
   age_days=(t-mark.tick)/17280
   freshness=max(0.,1-(t-mark.tick)/PREY_SCENT.lifetime)
   amount=prey_scent_strength(mark,t)
  end
 else
  cues=configured_scat_observe(saved.scat_state,origin...,t;radius=PREY_SCENT.radius)
  matches=[q for q in cues if q.kind==0x01 && (q.x,q.z)==obs.target && q.detail==obs.detail]
  if !isempty(matches)
   scores=[PREDATOR_SCAT_CUE.signal_scale*min(q.amount,PREDATOR_SCAT_CUE.amount_cap)*
    (PREDATOR_SCAT_CUE.old_weight+(1-PREDATOR_SCAT_CUE.old_weight)*q.freshness)/(1+distance) for q in matches]
   cue=matches[argmin(abs.(scores.-obs.signal))]
   freshness=cue.freshness;amount=cue.amount
   age_days=cue.detail==:fresh ? (1-cue.freshness)*SCAT_TRACE.fresh_ticks/17280 : nothing
  end
 end
 heading=atan(obs.target[2]-origin[2],obs.target[1]-origin[1])
 steered=p.mode==:hunt && p.visual.body.state==P.SEARCH && abs(P.angle_delta(p.visual.body.heading-heading))<1e-8
 (tick=t,kind=source=="body" ? "body" : "scat:"*string(obs.detail),signal=obs.signal,
  observation_age=t-obs.tick,freshness,age_days,amount,distance,position=origin,target=obs.target,
  steered,cautious=c.prey_scents.active_target[actor]!==nothing)
end
function replay(root,enabled;day=68,actor=2)
 saved=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls"))
 s=saved.world;c=saved.cohort;bird=saved.raptor
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 H.enable_rabbit_neighbor_batch!(s.world;gpu=false,audit=false,automatic=false)
 cue_rows=Any[];samples=Any[];cells=Set{Tuple{Int,Int}}();max_radius=0.;origin=nothing;tracked=Set{Int}();tracking_ticks=0;missing_sniffs=0;hint_sniffs=0;no_cue_ticks=0
 elapsed=@elapsed for t in s.ticks:(day+3)*17280-1
  configured_predator_replacement_update!(s,c,saved.migration,t;target=1)
  for m in c.minds;m.estimates["search_expansion_enabled"]=1.;m.estimates["no_cue_search_enabled"]=enabled ? 1. : 0.;end
  if t%17280==0
   was=bird.present;configured_raptor_population!(bird,count(s.alive),t)
   if !was && bird.present
    bird.visual.body.x,bird.visual.body.z=configured_raptor_edge(s.world,bird.destination)
   elseif bird.mode==:depart
    bird.destination=configured_raptor_edge(s.world,(bird.visual.body.x,bird.visual.body.z))
   end
  end
  p=c.predators[actor];origin===nothing && (origin=(p.visual.body.x,p.visual.body.z))
  animal_trial_prepare!(s,c.predators,t;scat_state=saved.scat_state,raptor=bird,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,present=saved.migration.present)
  if get(c.minds[actor].estimates,"search:sniff_tick",-1.)==t
   obs=c.prey_scents.observed[actor]
   push!(cue_rows,diagnose_cue(saved,s,p,c,actor,t,obs))
  end
  animal_trial_advance!(s,c.predators,t;rabbit_composition=saved.rabbit_composition,scat_state=saved.scat_state,scents=c.scents,minds=c.minds,prey_nutrition=.6,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach,present=saved.migration.present)
  configured_raptor_step!(bird,s,c.predators,t;rabbit_composition=saved.rabbit_composition,prey_nutrition=.5,present=saved.migration.present)
  e=c.minds[actor].estimates
  if get(e,"search:sniff_tick",-1.)==t
   if get(e,"search:missing_sniffs",0.)>0;missing_sniffs+=1;else;hint_sniffs+=1;end
  end
  no_cue_ticks+=get(e,"search:missing_sniffs",0.)>=PREDATOR_NO_CUE_SEARCH.missing_sniffs && 0<=t-get(e,"search:sniff_tick",-Inf)<=PREY_SCENT.sniff_interval
  b=p.visual.body
  if b.target>0;push!(tracked,b.target);tracking_ticks+=1;end
  push!(cells,(floor(Int,b.x/8),floor(Int,b.z/8)))
  max_radius=max(max_radius,hypot(b.x-origin[1],b.z-origin[2]))
  if t%720==0
   push!(samples,(tick=t,position=(b.x,b.z),food=p.food,H=c.minds[actor].loop.H,
     radius=get(c.minds[actor].estimates,"search:radius",0.),observations=p.visual.seen_by_rabbits))
  end
 end
 p=c.predators[actor];report=trial_predator_report(p)
 expected=deserialize(joinpath(root,"checkpoints/day-"*lpad(day+3,3,'0')*".jls"))
 matches=JSON3.write(report)==JSON3.write(trial_predator_report(expected.cohort.predators[actor]))
 # H-only baseline is compared below to the prior H-only replay.
 out=(cue_rows,missing_sniffs,hint_sniffs,no_cue_ticks,enabled,actor,day,seconds=elapsed,matches,alive=p.alive,captures=p.visual.body.captures,
 seen_by_rabbits=report.prey_observations,tracked_targets=length(tracked),tracking_ticks,spent=p.spent,eaten=p.eaten,food=p.food,
 cells=length(cells),max_displacement=max_radius,search=Dict(k=>v for (k,v) in c.minds[actor].estimates if startswith(k,"search:")),samples)
 println(JSON3.write(merge(out,(samples=nothing,cue_rows=nothing))))
 out
end
root=ARGS[1]
a=replay(root,true);b=replay(root,true;day=77,actor=5)
prior=JSON3.read(read(ARGS[3],String))
@testset "audit is observational" begin
 for (x,y) in ((a,prior.new),(b,prior.other_new))
  @test x.spent==y.spent && x.food==y.food && x.captures==y.captures
  @test x.cells==y.cells && x.max_displacement==y.max_displacement
 end
end
write(ARGS[2],JSON3.write((;a,b)))
