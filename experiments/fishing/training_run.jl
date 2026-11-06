using JSON3, Test
length(ARGS) in 1:3 || error("OUTPUT [DAYS] [INITIAL_FISH]")
root=abspath(ARGS[1]);days=length(ARGS)>=2 ? parse(Int,ARGS[2]) : 1
1<=days<=30 || error("days")
initial_fish=length(ARGS)==3 ? parse(Int,ARGS[3]) : 1
initial_fish>=1 || error("initial fish")
repo=normpath(joinpath(@__DIR__,"../.."));mkpath(root)
input=JSON3.read(read(joinpath(repo,"experiments/rock_gate/navigation_idle_10d_input.json"),String),Dict{String,Any})
cfg=input["config"];s=input["scene"];ids=["npc_a","npc_b","npc_c","npc_d"]
merge!(cfg,Dict("days"=>days,"home_observation"=>"off","daily_delivery"=>"on","ground"=>"flat","food"=>"finite","hazards"=>"off","night_fear"=>"off","regrowth_capacity"=>0))
merge!(s,Dict("name"=>"fishing-bank-smoke","configured_acorn_quest"=>false,"configured_acorn_tasting"=>false,
 "configured_quest_release"=>false,"configured_camp_landmark"=>false,"configured_camp_experience"=>false,
 "configured_camp_exterior"=>false,"post_return_idle"=>false,"post_return_meal"=>false,
 "sleep_external_gate"=>true,"food_security_provision"=>true,"typed_food"=>true,"game_proficiency"=>true,
 "initial_inventory"=>fill(0,4),"initial_inventory_kinds"=>[Int[] for _ in ids],"initial_personal_stock"=>fill(initial_fish,4),
 "initial_personal_food_counts"=>Dict(a=>[0,0,0,0,initial_fish] for a in ids)))
# A declared simplified bank fixture: spawn at the nearby camp, no commanded actions.
# Navigation, return, meals and choosing whether to cast remain ordinary policies.
s["positions"]=[[.3,6.],[-.3,6.],[0.,6.3],[0.,5.7]]
s["food"]=[Dict("x"=>0.,"z"=>10.,"stock"=>0,"renewable"=>false,"food_kind"=>5,
 "appearance"=>"fishing_water","acquisition"=>"fishing")]
for k in ("obstacles","low_obstacles","ground_patches","artificial_roads","hazards");s[k]=Any[];end
for k in ("landscape","complex_rocks","distinctive_landmarks","transfer_world");pop!(s,k,nothing);end
s["food_processing"] = true
s["food_facilities"]=[Dict("id"=>1,"x"=>0.,"z"=>6.,"work_radius"=>2.1,"height"=>1.,"radius"=>.5,"color"=>"brown","processing_kinds"=>[3,5])]
s["configured_fishing_training"]=true
s["configured_salt_tasting"]=true
s["loose_items"]=Any[Dict("id"=>i,"kind"=>4,"x"=>0.,"z"=>6.,"location"=>"stored","owner"=>a) for (i,a) in enumerate(ids)]
# One concentrated deposit; no instruction to visit or harvest it.
append!(s["loose_items"],[Dict("id"=>100+i,"kind"=>4,"x"=>8.,"z"=>12.) for i in 1:32])
snapshot=joinpath(root,"source");ispath(snapshot) && error("fresh output required")
mkpath(joinpath(snapshot,"integrations"));cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
write(joinpath(snapshot,"src/data/lw_actor_ids.jl"),"const IDS="*repr(Tuple(ids))*"\n")
write(joinpath(root,"input.json"),JSON3.write(input));cp(@__FILE__,joinpath(root,"runner.jl"))
write(joinpath(root,"conditions.json"),JSON3.write(Dict("days"=>days,"initial_fish_per_actor"=>initial_fish,"salt"=>"32 transferable crystals at (8,12), plus one owned tasting sample per actor; no harvest instruction or recipe", "actors"=>ids,"scene"=>"simplified declared fishing bank, no obstacles; actors spawn near the opportunity",
 "game_rules"=>"180 worked ticks per attempt; probability 0.25 to 0.45; completed miss also gives experience; stock zero; initial fish amount recorded separately",
 "fish"=>"fish kind 5, same-day conversion to inedible material; no tools, bait or species",
 "fixed_settings"=>["initial fishing technique knowledge and location fixture","existing daily return scheduling and night sleep gate"],
 "actions"=>"fixed training: taste initial fish then observe/lick owned salt at camp, one completed attempt (miss allowed), return; ordinary navigation")))
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
native_main([joinpath(root,"run"),"--spec",joinpath(root,"input.json"),"--checkpoint-dir",joinpath(root,"checkpoints")])
r=JSON3.read(read(joinpath(root,"run/result.json"),String))
fishing=r.food_resources.game_proficiency.fishing
@testset "fishing training integration: empty water" begin
 @test length(r.daily)==days
 @test r.initial_food==4initial_fish
 @test length(r.portable_items.items)==36
 initial_fish>=10 && (@test r.expired_fish>0)
 @test r.ground+r.consumed+sum(a.inventory+a.personal_stock for a in values(r.final_agents))==4initial_fish
 for a in ids
  q=r.mb_map[a].fishing_training
  @test q.stage=="completed"
  if days>=2 && initial_fish>=10
   @test r.mb_map[a].food_conditions.conditions.grey_flesh.usable==0
   @test r.mb_map[a].food_conditions.storage[Symbol("5")].unusable_episodes==1
  end
  @test count(e->e.kind=="fish_tasted",q.records)==1
  @test count(e->e.kind=="salt_tasted",q.records)==1
  @test sum(e.samples for e in values(r.mb_map[a].item_taste_experiences))==1
  @test only(filter(e->e.kind=="fish_tasted",q.records)).liking>0
  @test count(e->e.kind=="attempt_completed",q.records)==1
  @test !only(filter(e->e.kind=="attempt_completed",q.records)).caught
  @test fishing[a].attempts>=1
  @test fishing[a].caught==0
 end
end
write(joinpath(root,"completed.json"),JSON3.write(Dict("days"=>days,"verified"=>true)))
