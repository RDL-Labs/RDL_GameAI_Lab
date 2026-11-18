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
    @test configured_api_training_supply!(maps,2,200,100)["npc_e"]==Dict("kind"=>5,"quantity"=>1)
    @test isempty(configured_api_training_supply!(maps,2,200,100))
    @test configured_api_fish_active(fish)
    ENV["RDL_API_FIELD_TRAINING"]="1"
    configured_api_training_observe!("npc_e",maps["npc_e"],201)
    @test !configured_api_diary_due(10)
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
