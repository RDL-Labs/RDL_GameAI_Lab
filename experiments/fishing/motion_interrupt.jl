using Test, JSON3
include("../../src/lw/LW.jl")
Base.include(LW,joinpath(@__DIR__,"../../src/lw/perception/task_motion.jl"))
const A=first(LW.IDS)
const D=LW.D
out=length(ARGS)>0 ? abspath(ARGS[1]) : joinpath(@__DIR__,"../../outputs/fishing-motion-interrupt-20261106")
mkpath(out)

# Declared fixture: an already-started cast, stationary observer, no navigation
# policy before the first interruption. This isolates sensing from finding a site.
# Replace this harness with the normal task lifecycle when connected to LW day.
function scenario(mode;seed=1)
 w=LW.world(true);empty!(w.obstacles)
 for a in LW.IDS;w.inventory[a]=0;w.positions[a]=(0.,0.);end
 food=[(x=0.,z=1.,stock=20,food_kind=5,appearance="fishing_water",acquisition="fishing",renewable=false)]
 stock=[20];stores=Dict(a=>0 for a in LW.IDS)
 r=LW.food_resources((typed_food=true,),w,food,stock,0,stores)
 cargo=Dict(a=>Any[] for a in LW.IDS)
 yaw=Dict(a=>0. for a in LW.IDS)
 safety=LW.safety_state();loop=LW.BasicLoop("$A:safety";probabilistic=true,seed)
 h=(x=0.,z=28.,vx=0.,vz=-.2,start=0,stop=200)
 mode=="stationary" && (h=(x=0.,z=6.,vx=0.,vz=0.,start=0,stop=200))
 mode=="far" && (h=(x=0.,z=100.,vx=0.,vz=-.2,start=0,stop=200))
 mode=="occluded" && push!(w.obstacles,LW.RDLMigrationProbe.Circle(0.,3.,1.))
 mode=="harmless_motion" && (h=(x=-10.,z=6.,vx=.1,vz=0.,start=0,stop=200))
 rows=Any[];full=0;internal=0;notice_time=nothing;action=nothing
 LW.fishing_tick!(r,w,cargo,food,stock,A,1,0,"initial-cast")
 map=D()
 for t in 1:120
  q=(x=h.x+h.vx*t,z=h.z+h.vz*t,vx=h.vx,vz=h.vz)
  notice=LW.task_motion_notice(w.positions[A],yaw[A],[q];occluders=w.obstacles)
  if notice!==nothing
   full+=1;notice_time=t
   # Motion is not a threat verdict. Harmless control is absent from the existing
   # known-hazard channel; this classification is authored, not learned here.
   hazards=mode=="harmless_motion" ? Any[] : [h]
   ob=LW.hazard_observation(w,A,yaw,hazards,t)
   moves=LW.movement_observation(w,A,yaw,food,stock)
   plan=LW.safety_methods!(safety,loop,ob,moves,"interrupt:$t")
   action=plan===nothing ? "fish" : plan["action"]
   action!="fish" && LW.fishing_cancel!(r,A,t*1_000_000,"safety:"*action)
   push!(rows,D("second"=>t,"motion"=>notice,"hazards_seen"=>length(ob["features"]),"action"=>action))
   break # report first response, not a claim of successful escape
  end
  # Work/body and own outcome model continue without a fresh external observation.
  w.bodies[A],work_status,_,_=LW.step(w.bodies[A],"fish",w.inventory[A])
  work_status=="worked" || error("fixture body cannot continue fishing")
  LW.fishing_tick!(r,w,cargo,food,stock,A,1,t*1_000_000,"cast:$t")
  LW.acquisition_result!(map,"fishing",0,720.,1.,false)
  internal+=1
 end
 LW.food_audit!(r,w,stock,0,stores)
 fs=LW.fishing_state!(r,A)
 D("mode"=>mode,"seed"=>seed,"motion_at"=>notice_time,"first_action"=>action,
   "full_observations"=>full,"internal_updates"=>internal,"interrupted"=>fs["interrupted"],
   "active_ticks"=>fs["active"]===nothing ? nothing : fs["active"]["ticks"],"events"=>rows)
end
results=[scenario(mode) for mode in ("approach","stationary","far","occluded","harmless_motion")]
@testset "motion-only focused fishing" begin
 approach,stationary,far,occluded,harmless=results
 @test approach["motion_at"]==100
 @test approach["full_observations"]==1
 @test approach["internal_updates"]==99
 @test approach["interrupted"]==1
 for control in (stationary,far,occluded)
  @test control["full_observations"]==0
  @test control["internal_updates"]==120
  @test control["active_ticks"]==121
 end
 @test harmless["full_observations"]==1
 @test harmless["first_action"]=="fish"
 @test harmless["interrupted"]==0
end
responses=[scenario("approach";seed) for seed in 1:16]
write(joinpath(out,"result.json"),JSON3.write(D("scenarios"=>results,"seed_responses"=>responses,
 "scope"=>"isolated real fishing/safety components; no production lw_day focus gate yet; first response only")))
println(JSON3.write(results))
