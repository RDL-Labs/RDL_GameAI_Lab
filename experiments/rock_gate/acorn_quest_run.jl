using JSON3, Test, Serialization
repo=normpath(joinpath(@__DIR__,"../.."))
length(ARGS) in 1:6 || error("OUTPUT [tasting] [DAYS] [release] [normal] [INITIAL_STOCK]")
release=length(ARGS)>=4 && ARGS[4]=="release"
normal=length(ARGS)>=5 && ARGS[5]=="normal"
initial_stock=length(ARGS)>=6 ? parse(Int,ARGS[6]) : 60
initial_stock>=0 || error("initial stock must be nonnegative")
tasting=length(ARGS)>=2 && ARGS[2]=="tasting"
days=length(ARGS)>=3 ? parse(Int,ARGS[3]) : 2
2<=days<=180 || error("days must be 2..180")
root=abspath(first(ARGS));mkpath(root)
const last_day_wall=Ref(time_ns())
function record_quest_day(day,physical,maps,counts)
 wall=time_ns();seconds=(wall-last_day_wall[])/1e9;last_day_wall[]=wall
 row=Dict("day"=>day,"wall_seconds_since_previous_day"=>seconds,"physical"=>physical,
  "quest_stages"=>Dict(a=>m["training_quest"]["stage"] for (a,m) in maps),"cumulative_counts"=>counts)
 open(joinpath(root,"daily-progress.jsonl"),"a") do io;println(io,JSON3.write(row));end
 write(joinpath(root,"progress.json"),JSON3.write(Dict("completed_days"=>day,"target_days"=>days,"last_day_wall_seconds"=>seconds)))
end
input=JSON3.read(read(joinpath(@__DIR__,"navigation_idle_10d_input.json"),String),Dict{String,Any})
cfg=input["config"];s=input["scene"]
original_scene=deepcopy(s)
merge!(cfg,Dict("days"=>days,"daily_delivery"=>"off","night_fear"=>"off","ground"=>"flat","regrowth_capacity"=>0))
merge!(s,Dict("name"=>"acorn-training-quest","configured_acorn_quest"=>true,"configured_camp_exterior"=>true,"post_return_idle"=>false,"gradient_roll"=>true,"gradient_direction_distance"=>30.,"sleep_external_gate"=>true,"configured_routine_actions"=>true,"predictive_skyline"=>false))
s["obstacles"]=[s["obstacles"][1],Dict("x"=>8.,"z"=>14.,"height"=>8.,"radius"=>0.5,"color"=>"green","kind"=>1,"food_index"=>1,"solid"=>true,"world_id"=>2)]
s["food"]=[Dict("x"=>7.,"z"=>13.,"stock"=>20,"renewable"=>false,"food_kind"=>3,"appearance"=>"brown_capped_ovoid")]
s["configured_acorn_tasting"]=tasting;s["food_processing"]=tasting
if release
 cfg["daily_delivery"]="on"
 s["configured_quest_release"]=true;s["post_return_idle"]=true;s["post_return_meal"]=true
end
s["food_facilities"]=tasting ? [Dict("id"=>1,"name"=>"camp_food_workshop","x"=>-.8,"z"=>6.,"work_radius"=>2.1,"height"=>1.,"radius"=>.5,"color"=>"brown","processing_kinds"=>[3])] : Any[]
for k in ("low_obstacles","ground_patches","artificial_roads","hazards");s[k]=Any[];end
for k in ("landscape","complex_rocks","distinctive_landmarks","transfer_world");pop!(s,k,nothing);end
if normal
 for k in ("obstacles","food","low_obstacles","ground_patches","artificial_roads","landscape","complex_rocks","distinctive_landmarks")
  haskey(original_scene,k) && (s[k]=deepcopy(original_scene[k]))
 end
 cfg["ground"]="patches";s["name"]="ordinary-map-with-acorn-training"
 for f in s["food"]
  f["stock"]=20;f["renewable"]=false
  f["food_kind"]=f["appearance"]=="brown_capped_ovoid" ? 3 : 1
 end
 tree=Dict("x"=>4.,"z"=>12.,"height"=>8.,"radius"=>.5,"color"=>"green","kind"=>1,"food_index"=>length(s["food"])+1,"solid"=>true,"world_id"=>maximum(o["world_id"] for o in s["obstacles"])+1)
 @assert all(hypot(tree["x"]-o["x"],tree["z"]-o["z"])>tree["radius"]+o["radius"]+.5 for o in s["obstacles"])
 push!(s["obstacles"],tree)
 push!(s["food"],Dict("x"=>3.5,"z"=>11.,"stock"=>20,"renewable"=>false,"food_kind"=>3,"appearance"=>"brown_capped_ovoid"))
 @assert s["obstacles"][1:end-1]==original_scene["obstacles"]
 @assert [(f["x"],f["z"]) for f in s["food"][1:end-1]]==[(f["x"],f["z"]) for f in original_scene["food"]]
end
ids=["npc_a","npc_b","npc_c","npc_d"]
s["initial_personal_stock"]=fill(initial_stock,length(ids))
s["initial_personal_food_counts"]=Dict(a=>[initial_stock,0,0,0] for a in ids)
snapshot=joinpath(root,"source");ispath(snapshot) && error("fresh output required")
mkpath(joinpath(snapshot,"integrations"));cp(joinpath(repo,"src"),joinpath(snapshot,"src"));cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
write(joinpath(snapshot,"src/data/lw_actor_ids.jl"),"const IDS="*repr(Tuple(ids))*"\n")
day=joinpath(snapshot,"src/lw/simulation/day.jl");source=read(day,String)
needle="elseif ((food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) || forecast_request_ready)"
@assert length(findall(needle,source))==1
source=replace(source,needle=>"elseif false && ((food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) || forecast_request_ready)")
checkpoint_anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
@assert length(findall(checkpoint_anchor,source))==1
source=replace(source,checkpoint_anchor=>checkpoint_anchor*"\n            Main.record_quest_day(length(daily),physical(),mb_maps,counts)")
write(day,source)
write(joinpath(root,"input.json"),JSON3.write(input))
write(joinpath(root,"conditions.json"),JSON3.write(Dict("days"=>2,"actors"=>ids,"fixed_settings"=>["first-day camp tour including exterior look-back","quest objective switches on pickup and deposit","rest after quest completion","ordinary body maintenance and near-food pickup"],"disabled"=>["processing","daily delivery objective","night fear","aid initiation","exchange","wildlife","hazards"],"food"=>"one finite raw acorn site, 20 units","initial_stock"=>"60 fruit and one carried fruit per actor","navigation"=>"ordinary MB; no waypoint coordinate supplied by quest","source"=>snapshot)))
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
if tasting
 conditions=JSON3.read(read(joinpath(root,"conditions.json"),String),Dict{String,Any})
 filter!(!=("processing"),conditions["disabled"])
 push!(conditions["fixed_settings"],"collect two acorns; at camp retrieve raw/eat, retrieve raw/process 120 work ticks/eat, retrieve fruit/eat; gut-full waits")
 conditions["raw_acorn_model"]="edible, liking -1, same 20 energy; no toxicity model"
 conditions["food_facility"]="camp_food_workshop at (-0.8,6), work radius 2.1, acorn processing capability; visible nonblocking workbench"
 conditions["fruit_note"]="final comparison uses existing personal stock; fruit also supplies initial maintenance meals"
 write(joinpath(root,"conditions.json"),JSON3.write(conditions))
end
conditions=JSON3.read(read(joinpath(root,"conditions.json"),String),Dict{String,Any})
conditions["days"]=days
conditions["initial_stock"]="$initial_stock fruit in personal storage plus one carried fruit per actor"
conditions["food_security_provision"]=Dict("enabled"=>get(s,"food_security_provision",release),"source"=>"same owner-local forecast as food trade/aid", "choice"=>"stay at camp or start provisioning; daily or rising-shortfall reconsideration", "stay"=>"ordinary rest with meals/processing/social responses; no new cognition shutdown")
conditions["game_proficiency"]=Dict("enabled"=>get(s,"game_proficiency",true),"rule"=>"logarithmic-v1","experience"=>"one per completed processing; pre-completion quality", "quality"=>"four discrete grades, affects taste only; no boredom", "scope"=>"game skill MB forecast, no processing-request negotiation")
if normal
 conditions["map"]="original 166 obstacles and terrain preserved, one training tree added; original 17 food locations preserved"
 conditions["food"]="18 sites x 20 finite units: 9 fruit, 9 raw acorn including training; no regeneration"
 conditions["training_focus"]="observed acorn appearance only while outbound; ordinary perception retained; no world coordinate guidance"
end
if release
 filter!(x->!(x in ("rest after quest completion","daily delivery objective")),conditions["fixed_settings"])
 filter!(!=("daily delivery objective"),conditions["disabled"])
 append!(conditions["fixed_settings"],["release quest the morning after final tasting to ordinary daily exploration and return","after return process if necessary and eat before cognition pause until night; physiology continues"])
end
conditions["timing_note"]="daily wall intervals include checkpoint writes; first includes compilation and setup"
write(joinpath(root,"conditions.json"),JSON3.write(conditions))
@test collect(IDS)==ids
native_main([joinpath(root,"run"),"--spec",joinpath(root,"input.json"),"--checkpoint-dir",joinpath(root,"checkpoints")])
r=JSON3.read(read(joinpath(root,"run/result.json"),String))
training=r.daily[2]
write(joinpath(root,"quest-review.json"),JSON3.write(Dict(a=>r.mb_map[a].training_quest for a in ids)))
@testset "quest integration" begin
 @test length(r.daily)==days
 @test length(r.final_agents)==4
 @test all(get(c,:process_food,0)==(tasting ? 120 : 0) for c in values(training.counts))
 @test training.food_resources.consumed[3]==(tasting ? 4 : 0)
 @test training.food_resources.consumed[4]==(tasting ? 4 : 0)
 @test training.ground==(normal ? 360 : 20)-(tasting ? 8 : 4)
 @test all(get(c,:pickup,0)==0 for c in values(r.daily[1].counts))
 for a in ids
  q=r.mb_map[a].training_quest
  @test q.stage=="completed"
  @test q.delivered==(tasting ? 2 : 1)
  expected=["quest_started","tree_food_area_reached","acorn_acquired"]
  tasting && push!(expected,"acorn_acquired")
  append!(expected,["home_reached","acorn_deposited"])
  tasting && append!(expected,["raw_tasted","processing_completed","processed_tasted","fruit_tasted"])
  @test [e.kind for e in q.records]==expected
  if tasting
   @test only(e.liking for e in q.records if e.kind=="raw_tasted")<0
   @test only(e.liking for e in q.records if e.kind=="processed_tasted")>0
   @test only(e.liking for e in q.records if e.kind=="fruit_tasted")>0
   @test r.mb_map[a].food_taste_experiences.brown_capped_ovoid.samples>=1
   @test sum(v.samples for (k,v) in pairs(r.mb_map[a].food_taste_experiences) if String(k)=="brown_meal" || startswith(String(k),"brown_meal:quality:");init=0)>=1
   @test training.food_resources.processed_inputs[3]==4
   @test all(e.food_facility_id==1 for e in r.events if e.actor==a && e.action=="process_food" && e.status in ("processing","processed"))
  end
  @test !isempty(q.records) && q.records[1].us>=17_280_000_000
  @test r.home_observation[a].completed
  @test r.home_observation[a].camp_landmark.tour_completed
 end
end
if release
 @testset "meal precedes each cognition pause" begin
  for a in ids
   pauses=[e for e in r.events if e.actor==a && e.method=="configured_post_return_idle"]
   @test !isempty(pauses)
   for pause in pauses
    @test any(e->e.actor==a && e.action=="eat" && e.status=="ate" && fld(e.us,17_280_000_000)==fld(pause.us,17_280_000_000) && e.us<pause.us,r.events)
   end
  end
  for day in r.daily
   @test r.initial_food+day.replenished_food==day.ground+day.shared_stock+day.consumed+sum(a.inventory+a.personal_stock for a in values(day.physical))
  end
 end
end
write(joinpath(root,"completed.json"),JSON3.write(Dict("days"=>days,"verified"=>true,"release"=>release)))
println("QUEST VERIFIED");flush(stdout)
