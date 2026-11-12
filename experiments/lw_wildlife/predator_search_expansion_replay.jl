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
function replay(root,enabled;day=68,actor=2)
 saved=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls"))
 s=saved.world;c=saved.cohort;bird=saved.raptor
 P.configured_predator_terrain_enable!(s.world;enabled=true)
 H.enable_rabbit_neighbor_batch!(s.world;gpu=false,audit=false,automatic=false)
 samples=Any[];cells=Set{Tuple{Int,Int}}();max_radius=0.;origin=nothing;tracked=Set{Int}();tracking_ticks=0
 elapsed=@elapsed for t in s.ticks:(day+3)*17280-1
  configured_predator_replacement_update!(s,c,saved.migration,t;target=1)
  for m in c.minds;m.estimates["scent_all_strengths"]=0.;m.estimates["search_expansion_enabled"]=enabled ? 1. : 0.;m.estimates["no_cue_search_enabled"]=0.;end
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
  animal_trial_advance!(s,c.predators,t;rabbit_composition=saved.rabbit_composition,scat_state=saved.scat_state,scents=c.scents,minds=c.minds,prey_nutrition=.6,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach,present=saved.migration.present)
  configured_raptor_step!(bird,s,c.predators,t;rabbit_composition=saved.rabbit_composition,prey_nutrition=.5,present=saved.migration.present)
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
 !enabled && @test matches
 out=(enabled,actor,day,seconds=elapsed,matches,alive=p.alive,captures=p.visual.body.captures,
 seen_by_rabbits=report.prey_observations,tracked_targets=length(tracked),tracking_ticks,spent=p.spent,eaten=p.eaten,food=p.food,
 cells=length(cells),max_displacement=max_radius,search=Dict(k=>v for (k,v) in c.minds[actor].estimates if startswith(k,"search:")),samples)
 println(JSON3.write(merge(out,(samples=nothing,))))
 out
end
root=ARGS[1];out=ARGS[2]
old=replay(root,false);new=replay(root,true)
other_old=replay(root,false;day=77,actor=5);other_new=replay(root,true;day=77,actor=5)
write(out,JSON3.write((old,new,other_old,other_new)))

