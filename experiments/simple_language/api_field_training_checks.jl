using Test,JSON3
const OUTPUT=mktempdir()
include("../../integrations/lightweight_julia/native.jl")
include("../../src/lw/configured_paths/api_trade_agent.jl")
include("../../src/lw/configured_paths/api_field_training.jl")
include("api_field_training_instrument.jl")
@testset "Sequential field curriculum" begin
    q=configured_acorn_quest_state(;tasting=true)
    fish=configured_fishing_training_state();fish["stage"]="waiting_acorn"
    maps=Dict("npc_e"=>Dict("training_quest"=>q,"fishing_training"=>fish))
    @test !configured_api_fish_active(fish)
    configured_api_training_observe!("npc_e",maps["npc_e"],0;observed=Dict("color"=>"orange"),heading=0.)
    @test CONFIGURED_API_HISTORY[end].event=="training_observation"
    @test isempty(configured_api_training_supply!(maps,0,0,100))
    configured_acorn_quest_request!(q,true,100,100,true,[])
    configured_acorn_quest_request!(q,true,101,100,false,[Dict("appearance"=>"brown_capped_ovoid","distance"=>1.)])
    for source in ("one","two");configured_acorn_quest_result!(q,"pickup","picked_up",102;kind=3,source);end
    @test q["stage"]=="return"
    configured_acorn_quest_result!(q,"deposit","performed",103;delivered=["one","two"])
    configured_acorn_quest_result!(q,"eat","ate",104;kind=3)
    configured_acorn_quest_result!(q,"process_food","processed",105)
    configured_acorn_quest_result!(q,"eat","ate",106;kind=4)
    configured_acorn_quest_result!(q,"eat","ate",107;kind=1)
    @test q["stage"]=="completed"
    @test isempty(configured_api_training_supply!(maps,1,199,100))
    @test isempty(configured_api_training_supply!(maps,2,200,100)) # activation, handover waits for home
    @test isempty(configured_api_training_supply!(maps,2,200,100))
    @test configured_api_fish_active(fish)
    ENV["RDL_API_FIELD_TRAINING"]="1"
    configured_api_training_observe!("npc_e",maps["npc_e"],201)
    @test configured_api_diary_due(1)
    configured_fishing_training_result!(fish,"eat","ate",RDLBody.COOKED_FISH,true,202)
    @test fish["stage"]=="trial"
    configured_fishing_training_result!(fish,"fish","no_catch",0,false,203)
    @test fish["stage"]=="return"
    configured_fishing_training_result!(fish,"walk","performed",0,true,204)
    configured_api_training_observe!("npc_e",maps["npc_e"],205)
    @test CONFIGURED_API_LESSON[].completed
    @test configured_api_diary_due(2) # stage, not calendar, determines graduation
    @test !configured_api_fish_active(fish)
    configured_api_training_report!(maps,3,300)
    @test isfile(joinpath(OUTPUT,"field-training-progress.json"))
    delete!(ENV,"RDL_API_FIELD_TRAINING")
    source=read("src/lw/simulation/day.jl",String)
    source=replace(source,"            replenished+=configured_personal_food_supply!"=>"            day>=3 && (personal_supply=nothing)\n            replenished+=configured_personal_food_supply!")
    patched=api_field_training_instrument(source)
    @test occursin("configured_api_training_supply!",patched)
    @test !occursin("fishing_training_requires_initial_tasting_sample",patched)
end
@testset "Teacher handover and material shortage" begin
    w=world(true)
    for a in IDS;w.inventory[a]=0;end
    stores=Dict(a=>0 for a in IDS)
    foods=food_resources((typed_food=true,food_batch_expiry=true),w,Any[],Int[],0,stores)
    cargo=Dict(a=>Any[] for a in IDS);ledger=Any[];a=first(IDS)
    q=configured_acorn_quest_state(;tasting=true);q["stage"]="taste_fruit"
    fish=configured_fishing_training_state();fish["stage"]="waiting_acorn"
    map=Dict{String,Any}("training_quest"=>q,"fishing_training"=>fish)
    @test configured_api_teacher_handover!(map,foods,w,cargo,ledger,a,false,1)==0
    @test configured_api_teacher_handover!(map,foods,w,cargo,ledger,a,true,2)==1
    @test foods.inventory[a]==[1]
    @test foods.added[1]==w.inventory[a]==length(cargo[a])==1
    @test length(foods.game.age.inventory[a])==1
    restored=deepcopy(map)
    @test configured_api_teacher_handover!(restored,foods,w,cargo,ledger,a,true,3)==0
    @test length(ledger)==1
    plan=D("action"=>"retrieve","food_kind"=>1)
    @test configured_api_training_available_plan(q,plan,UInt8[],zeros(Int,8),4)===nothing
    @test configured_api_training_available_plan(q,plan,UInt8[],zeros(Int,8),5)===nothing
    @test count(r->r["kind"]=="teacher_material_unavailable",q["records"])==1
    stock=zeros(Int,8);stock[1]=1
    @test configured_api_training_available_plan(q,plan,UInt8[],stock,6)===plan
    @test !q["material_wait"]
    q["stage"]="completed";fish["stage"]="taste"
    @test configured_api_teacher_handover!(map,foods,w,cargo,ledger,a,true,7)==1
    @test foods.inventory[a]==[1,5]
    @test sum(foods.added)==w.inventory[a]==length(cargo[a])==2
end
