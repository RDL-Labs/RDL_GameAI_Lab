using JSON3, Test
length(ARGS) in (1,2) || error("OUTPUT [DAYS]")
root=abspath(ARGS[1]);days=length(ARGS)==2 ? parse(Int,ARGS[2]) : 1
1<=days<=30 || error("days")
repo=normpath(joinpath(@__DIR__,"../.."));mkpath(root)
input=JSON3.read(read(joinpath(repo,"experiments/rock_gate/navigation_idle_10d_input.json"),String),Dict{String,Any})
cfg=input["config"];s=input["scene"];ids=["npc_a","npc_b","npc_c","npc_d"]
merge!(cfg,Dict("days"=>days,"home_observation"=>"off","daily_delivery"=>"on","ground"=>"flat","food"=>"finite","hazards"=>"off","night_fear"=>"off","regrowth_capacity"=>0))
merge!(s,Dict("name"=>"fishing-bank-smoke","configured_acorn_quest"=>false,"configured_acorn_tasting"=>false,
 "configured_quest_release"=>false,"configured_camp_landmark"=>false,"configured_camp_experience"=>false,
 "configured_camp_exterior"=>false,"post_return_idle"=>false,"post_return_meal"=>false,
 "sleep_external_gate"=>true,"food_security_provision"=>true,"typed_food"=>true,"game_proficiency"=>true,
 "initial_inventory"=>fill(0,4),"initial_inventory_kinds"=>[Int[] for _ in ids],"initial_personal_stock"=>fill(0,4),
 "initial_personal_food_counts"=>Dict(a=>[0,0,0,0] for a in ids)))
# A declared simplified bank fixture: spawn at the nearby camp, no commanded actions.
# Navigation, return, meals and choosing whether to cast remain ordinary policies.
s["positions"]=[[.3,6.],[-.3,6.],[0.,6.3],[0.,5.7]]
s["food"]=[Dict("x"=>0.,"z"=>10.,"stock"=>40,"renewable"=>false,"food_kind"=>5,
 "appearance"=>"fishing_water","acquisition"=>"fishing")]
for k in ("obstacles","low_obstacles","ground_patches","artificial_roads","hazards");s[k]=Any[];end
for k in ("landscape","complex_rocks","distinctive_landmarks","transfer_world");pop!(s,k,nothing);end
snapshot=joinpath(root,"source");ispath(snapshot) && error("fresh output required")
mkpath(joinpath(snapshot,"integrations"));cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
write(joinpath(snapshot,"src/data/lw_actor_ids.jl"),"const IDS="*repr(Tuple(ids))*"\n")
write(joinpath(root,"input.json"),JSON3.write(input));cp(@__FILE__,joinpath(root,"runner.jl"))
write(joinpath(root,"conditions.json"),JSON3.write(Dict("days"=>days,"actors"=>ids,"scene"=>"simplified declared fishing bank, no obstacles; actors spawn near the opportunity",
 "game_rules"=>"180 worked ticks per attempt; probability 0.25 to 0.45; completed miss also gives experience; stock finite 40",
 "fish"=>"fish kind 5, same-day expiry; no tools, bait or species",
 "fixed_settings"=>["initial fishing technique knowledge and location fixture","existing daily return scheduling and night sleep gate"],
 "actions"=>"not forced; ordinary candidate selection and physiology")))
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
native_main([joinpath(root,"run"),"--spec",joinpath(root,"input.json"),"--checkpoint-dir",joinpath(root,"checkpoints")])
r=JSON3.read(read(joinpath(root,"run/result.json"),String))
fishing=r.food_resources.game_proficiency.fishing
@testset "fishing world integration" begin
 @test length(r.daily)==days
 @test sum(s.attempts for s in values(fishing))>0
 @test sum(s.caught for s in values(fishing))>0
 @test r.initial_food==40
 @test r.ground+r.consumed+sum(a.inventory+a.personal_stock for a in values(r.final_agents))==40
 for a in keys(fishing)
  @test fishing[a].caught<=fishing[a].attempts
  skills=get(r.food_resources.game_proficiency.skills,a,Dict())
  @test get(get(skills,:fishing,Dict()),:completed,0)==fishing[a].attempts
 end
 @test all(e.action=="fish" for e in r.events if e.status=="picked_up")
end
write(joinpath(root,"completed.json"),JSON3.write(Dict("days"=>days,"verified"=>true)))
