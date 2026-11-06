using JSON3, Test
length(ARGS) in 1:11 || error("OUTPUT [DAYS] [ordinary|relaxed|abundant] [trade-on|trade-off] [idle-on|idle-off] [social-on|social-off] [normal|scarce] [RABBIT_COUNT] [finite|seasonal] [breed-off|breed-on] [empty|mixed-pregnancy]")
pregnancy_profile=length(ARGS)>=11 ? ARGS[11] : "empty"
pregnancy_profile in ("empty","mixed-pregnancy") || error("unknown pregnancy profile")
breeding_profile=length(ARGS)>=10 ? ARGS[10] : "breed-off"
breeding_profile in ("breed-off","breed-on") || error("unknown breeding profile")
pregnancy_profile=="empty" || breeding_profile=="breed-on" || error("mixed pregnancy requires breed-on")
supply_profile=length(ARGS)>=9 ? ARGS[9] : "finite"
supply_profile in ("finite","seasonal") || error("unknown supply profile")
rabbit_count=length(ARGS)>=8 ? parse(Int,ARGS[8]) : 0
0<=rabbit_count<=10000 || error("rabbit count must be 0..10000")
food_profile=length(ARGS)>=7 ? ARGS[7] : "normal"
food_profile in ("normal","scarce") || error("unknown food profile")
initial_fruit=food_profile=="scarce" ? 2 : 5
fish_total=food_profile=="scarce" ? 60 : 240
social_profile=length(ARGS)>=6 ? ARGS[6] : "social-on"
social_profile in ("social-on","social-off") || error("unknown social profile")
idle_profile=length(ARGS)>=5 ? ARGS[5] : "idle-off"
idle_profile in ("idle-on","idle-off") || error("unknown idle profile")
trade_idle=idle_profile=="idle-on"
days=length(ARGS)>=2 ? parse(Int,ARGS[2]) : 30
catch_profile=length(ARGS)>=3 ? ARGS[3] : "ordinary"
trade_profile=length(ARGS)>=4 ? ARGS[4] : "trade-on"
trade_profile in ("trade-on","trade-off") || error("unknown trade profile")
catch_profile in ("ordinary","relaxed","abundant") || error("unknown catch profile")
1<=days<=180 || error("days must be between 1 and 180")
include("river_scene.jl")
root=abspath(ARGS[1]);repo=normpath(joinpath(@__DIR__,"../.."));mkpath(root)
input=JSON3.read(read(joinpath(repo,"outputs/provision-stock5-normal-30d-20261104/input.json"),String),Dict{String,Any})
c=input["config"];s=input["scene"];ids=["npc_a","npc_b","npc_c","npc_d"]
merge!(c,Dict("days"=>days,"home_observation"=>"off","daily_delivery"=>"on","hazards"=>"off","night_fear"=>"off","food"=>"finite","regrowth_capacity"=>0))
merge!(s,Dict("name"=>"ordinary-fish-salt-spoilage-$(days)d","configured_acorn_quest"=>false,"configured_acorn_tasting"=>false,"configured_quest_release"=>false,
 "configured_camp_landmark"=>false,"configured_camp_experience"=>false,"configured_camp_exterior"=>false,
 "configured_fishing_training"=>true,"configured_salt_tasting"=>false,"configured_salted_fish_sample"=>true,"incidental_items"=>true,"post_return_idle"=>trade_idle,"post_return_meal"=>trade_idle,"configured_trade_idle"=>trade_idle,
 "social_relationships"=>social_profile=="social-on","task_focus"=>true,"task_interrupt_shield"=>true,"food_security_provision"=>true,"sleep_external_gate"=>true,"collapse_cognition_gate"=>true,"typed_food"=>true,"food_batch_expiry"=>true,"game_proficiency"=>true,
 "item_exchange"=>trade_profile=="trade-on","configured_trade_work_wait"=>trade_profile=="trade-on","configured_negotiation"=>trade_profile=="trade-on","food_exchange"=>false,
 "initial_inventory"=>fill(0,4),"initial_inventory_kinds"=>[Int[] for _ in ids],"initial_personal_stock"=>fill(initial_fruit+1,4),
 "initial_personal_food_counts"=>Dict(a=>[initial_fruit,0,0,0,0,0,0,1] for a in ids)))
if food_profile=="scarce"
 # World supply fixture: plentiful storable acorns, scarcer ready-to-eat fruit.
 for f in s["food"]; f["stock"]=min(f["stock"],get(f,"food_kind",1)==3 ? 9 : 6); end
end
for facility in get(s,"food_facilities",Any[]); 5 in facility["processing_kinds"] || push!(facility["processing_kinds"],5); end
push!(s["food_facilities"],Dict("id"=>maximum(f["id"] for f in s["food_facilities"])+1,
 "name"=>"camp_waste_bin","x"=>s["home"][1]+0.8,"z"=>s["home"][2],
 "height"=>0.6,"radius"=>0.4,"work_radius"=>2.1,"color"=>"grey","processing_kinds"=>Int[],"accepts_waste"=>true))
river=add_river_fishing!(s;total=fish_total,catch_profile=catch_profile)
if supply_profile=="seasonal"
    # World fixture, not agent knowledge: daily supply over a 60-day cosine cycle.
    # Rates are fractions of site capacity/day; nominal total 1..10 units/day
    # when all natural sites have room. No banked overflow or dropped-item renewal.
    for f in s["food"];f["renewable"]=get(f,"food_kind",1) in (1,3,5);end
    supply_capacity=sum(f["stock"] for f in s["food"] if f["renewable"])
    supply_capacity>0 || error("seasonal supply needs positive capacity")
    c["food"]="renewable";c["regrowth_days"]=1
    s["food_season"]=Dict("period_days"=>60,"low_rate"=>1/supply_capacity,"high_rate"=>10/supply_capacity,"phase_days"=>0)
end
s["loose_items"]=Any[]
s["wildlife"]=Dict{String,Any}("enabled"=>rabbit_count>0,"count"=>max(1,rabbit_count),"seed"=>20261028,"reproduction"=>breeding_profile=="breed-on")
s["wildlife"]["initial_pregnancy_days"]=pregnancy_profile=="mixed-pregnancy" ? [26,21,16,11,6] : Int[]
append!(s["loose_items"],[Dict("id"=>100+i,"kind"=>4,"x"=>8.,"z"=>12.) for i in 1:32])
source=joinpath(root,"source");ispath(source) && error("fresh output required")
mkpath(joinpath(source,"integrations"));cp(joinpath(repo,"src"),joinpath(source,"src"));cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(source,"integrations/lightweight_julia"))
write(joinpath(source,"src/data/lw_actor_ids.jl"),"const IDS="*repr(Tuple(ids))*"\n")
const previous_wall=Ref(time_ns())
function record_fishing_day(day,physical,maps,counts)
 wall=time_ns();elapsed=(wall-previous_wall[])/1e9;previous_wall[]=wall
 row=Dict("day"=>day,"wall_seconds"=>elapsed,"physical"=>physical,"counts"=>counts,
 "training"=>Dict(a=>m["fishing_training"]["stage"] for (a,m) in maps),
 "storage_learning"=>Dict(a=>get(get(m,"food_conditions",Dict()),"storage",Dict()) for (a,m) in maps))
 open(joinpath(root,"daily-progress.jsonl"),"a") do io;println(io,JSON3.write(row));end
 write(joinpath(root,"progress.json"),JSON3.write(Dict("completed_days"=>day,"target_days"=>days,"last_day_seconds"=>elapsed)))
end
p=joinpath(source,"src/lw/simulation/day.jl");code=read(p,String)
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
@assert length(findall(anchor,code))==1
write(p,replace(code,anchor=>anchor*"\n            Main.record_fishing_day(length(daily),physical(),mb_maps,counts)"))
write(joinpath(root,"input.json"),JSON3.write(input));cp(@__FILE__,joinpath(root,"runner.jl"));cp(joinpath(@__DIR__,"river_scene.jl"),joinpath(root,"river_scene.jl"))
write(joinpath(root,"conditions.json"),JSON3.write(Dict("days"=>days,"actors"=>ids,"seed"=>c["seed"],"sensitivities"=>c["mb_sensitivities"],"item_exchange"=>s["item_exchange"],
 "base"=>"provision-stock5-normal-30d-20261104/input.json; original terrain and fruit/acorn sites",
 "land_food_supply"=>food_profile=="scarce" ? "fruit up to 6/site, raw acorn up to 9/site; 54 fruit and 81 acorns on current map" : "original site stocks",
 "food_profile"=>food_profile,"river"=>river,"fish_stock"=>fish_total,"expiry_origin"=>"harvest/capture day; unharvested supply has no deadline; dropped food retains deadline","food_lifetimes_days"=>[5,2,30,10,1,0,1,1],"appearance"=>"fresh / faded / spoiled; no exact deadlines in sensory view","disposal"=>"camp bin, radius 2.1; initial knowledge of use; probabilistic disposal, one unit per action; waste ledger conserved",
 "initial"=>"$initial_fruit fruit + 1 grilled salted fish per actor; no carried food","salt"=>"32 at (8,12), visual display only, no owned samples",
 "fixed"=>["salt-grilled fish taste, rock salt appearance, one cast then return","existing daily return scheduling","initial fishing technique and processing recipe knowledge"],
 "configured_trade_work_wait"=>s["configured_trade_work_wait"],"trade_work_wait_rule"=>"fixed: defer selected offer while partner processes food; rest locally, then revalue; previous-tick work shortcut; replace with communication",
 "social_relationships"=>s["social_relationships"],"social_profile"=>social_profile,
 "fishing_body_rule"=>"low-load shore average: reserve .025*RS/tick, strain recovery .015*SS*rest recovery factor/tick; basal metabolism separate; processing unchanged; 180 ticks/cast",
 "task_focus"=>s["task_focus"],"task_focus_rule"=>"fish/process continuity; body, phase, completion or maximum 64 seconds trigger review; internal results continue",
 "task_interrupt_shield"=>s["task_interrupt_shield"],"task_interrupt_rule"=>"provisional fixed: food anxiety and work progress narrow motion response radius; nearby visible motion wakes; replace with learned attention",
 "configured_negotiation"=>s["configured_negotiation"],"negotiation_rule"=>"initial offer plus at most 3 adjustments; prefer feasible adjustment to immediate decline; agreement never forced; unchanged 30-second total deadline",
 "trade_idle"=>trade_idle,"trade_idle_rule"=>"after return meal and trade decision, suspend until addressed offer; next day resets; sleep remains separate",
 "supply_profile"=>supply_profile,"food_season"=>get(s,"food_season",nothing),"regrowth_rule"=>"seasonal only: daily natural fruit/acorn/fish replenishment capped by original site stocks; no harvest expiry reset; no loose-item regeneration",
 "wildlife"=>s["wildlife"],"wildlife_rule"=>"grazing rabbits; displacement wakes motion sensor; visible appearance on inspection, no threat label, no hunting",
 "breeding_profile"=>breeding_profile,"breeding_fixed"=>breeding_profile=="breed-on" ? "provisional FSM: nest-bound young and maternal nursing return with local potential; no predators, age death or disease; allocation limit stops experiment" : "disabled",
 "nursing_potential"=>breeding_profile=="breed-on","pregnancy_profile"=>pregnancy_profile,
 "breeding_observation_limit"=>"31-day gestation; mixed profile seeds 5 mothers due on days 5/10/15/20/25; partial nursing completion remains unchanged",
 "initial_pregnancy_accounting"=>"initial pregnancy investment and conceptions include pre-run history; subtract initial 5 conceptions for mixed profile when reporting new conceptions",
 "off"=>["acorn/home training","hazards","night fear","food-only exchange"],
 "on"=>["incidental pickup",trade_profile,"food security","spoilage observation and learning","sleep external gate","collapse cognition gate","proficiency"],"food_sites"=>s["food"])))
include(joinpath(source,"integrations/lightweight_julia/native.jl"))
@assert collect(IDS)==ids
native_main([joinpath(root,"run"),"--spec",joinpath(root,"input.json"),"--checkpoint-dir",joinpath(root,"checkpoints")])
r=JSON3.read(read(joinpath(root,"run/result.json"),String))
@test length(r.daily)==days
if trade_profile=="trade-off"
    @test get(r.portable_items.counts,:exchanged,0)==0
    @test get(r.portable_items.counts,:offered,0)==0
end
@test r.initial_food+r.replenished_food==r.ground+r.consumed+sum(r.food_resources.waste.counts)+sum(a.inventory+a.personal_stock for a in values(r.final_agents))
write(joinpath(root,"completed.json"),JSON3.write(Dict("days"=>days,"verified"=>true)))
