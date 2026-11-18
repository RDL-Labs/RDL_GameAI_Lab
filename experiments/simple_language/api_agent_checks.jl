using JSON3,Test
const OUTPUT=mktempdir()
include("../../src/lw/configured_paths/api_trade_agent.jl")
@testset "Aid remains available in scarcity" begin
    @test configured_api_aid_allowed()
end
@testset "API projection boundary" begin
    candidate=Dict("action"=>"item_accept","offer_id"=>"x","partner"=>"npc_a",
        "MB"=>"PRIVATE_SENTINEL","priority"=>999.,"expected"=>999.)
    offer=Dict("id"=>"x","give_food"=>[0,0,0,0,0,0,0,2],"want_food"=>[1,0,0,0,0,0,0,0],"give_items"=>Int[],"want_items"=>Int[])
    projected=configured_api_option(candidate,Dict("incoming"=>[offer]),1)
    @test projected.give==Dict("ネポ"=>1)
    @test projected.receive==Dict("パネ"=>2)
    @test !occursin("PRIVATE_SENTINEL",JSON3.write(projected))
    @test !occursin("expected",JSON3.write(projected))
    configured_api_meal!("npc_a",1,.8,1,80.,80.)
    @test isempty(CONFIGURED_API_HISTORY)
    configured_api_meal!("npc_e",1,.8,1,80.,80.)
    @test length(CONFIGURED_API_HISTORY)==2
    configured_api_public!("npc_e",nothing,nothing,2)
    @test length(CONFIGURED_API_HISTORY)==2
    configured_api_public!("npc_a",(text="秘密",motion=nothing,appearances=[]),nothing,2)
    @test length(CONFIGURED_API_HISTORY)==2
end
@testset "Budget diagnostics are not experienced" begin
    before=length(CONFIGURED_API_HISTORY)
    configured_api_record!((event="configured_cap",us=999,action="continue"))
    @test length(CONFIGURED_API_HISTORY)==before
    @test occursin("configured_cap",read(joinpath(OUTPUT,"api-events.jsonl"),String))
end
@testset "Free expression replaces authored signal" begin
    event=(id="test",actor="npc_e",role=:initiative,text="モ",motion="present",appearances=["fruit-form"])
    CONFIGURED_API_EXPRESSIONS[123]=(speech="果実はいかが？",gesture="withdraw",action="item_offer")
    emitted=configured_api_expression(event,123)
    @test emitted.text=="果実はいかが？"
    @test emitted.motion=="withdraw"
    @test emitted.appearances==event.appearances
    @test !haskey(CONFIGURED_API_EXPRESSIONS,123)
    @test configured_api_expression(event,123).text==""
    @test configured_api_expression(merge(event,(actor="npc_a",)),123)==merge(event,(actor="npc_a",))
end
@testset "Scarce supply leaves other actors intact" begin
    supply=Dict("npc_a"=>Dict("kind"=>1,"quantity"=>2),"npc_e"=>Dict("kind"=>8,"quantity"=>2))
    @test configured_api_supply(supply,3;scarce=false)===supply
    for day in 0:2
        @test configured_api_supply(supply,day;scarce=true)["npc_e"]["quantity"]==1
    end
    @test configured_api_supply(supply,3;scarce=true)["npc_e"]["quantity"]==0
    @test configured_api_supply(supply,12;scarce=true)["npc_e"]["quantity"]==0
    @test configured_api_supply(supply,12;scarce=true)["npc_a"]==supply["npc_a"]
    @test supply["npc_e"]["quantity"]==2
    decoded=JSON3.read(JSON3.write(supply))
    @test configured_api_supply(decoded,3;scarce=true)["npc_e"]["quantity"]==0
    @test configured_api_supply(decoded,2;scarce=true)["npc_a"]["quantity"]==2
end

@testset "Opaque food and body education" begin
    @test length(unique(CONFIGURED_API_FOODS))==8
    encoded=configured_api_input((stock=Dict("塩焼き魚"=>1),seen=["fruit-form","meal-form"],lesson=CONFIGURED_API_BODY_LESSON))
    @test !occursin("塩焼き魚",encoded)
    @test !occursin("fruit-form",encoded)
    @test occursin("パネ",encoded) && occursin("形カ",encoded)
    @test occursin("時間差",encoded)
    before=length(CONFIGURED_API_HISTORY)
    configured_api_meal!("npc_e",4,.3,4*17_280_000_000,70.,70.)
    @test length(CONFIGURED_API_HISTORY)==before+1
    @test CONFIGURED_API_HISTORY[end].food=="トセ"
end
@testset "Collapse lesson and post-education diary" begin
    include("../../src/lw/configured_paths/collapse_gate.jl")
    @test configured_collapse_active((reserve=0.,))
    @test !configured_collapse_active((reserve=0.001,))
    @test !configured_collapse_active((reserve=0.,);enabled=false)
    @test !any(configured_api_diary_due,1:3)
    @test all(configured_api_diary_due,4:5)
    @test configured_api_diary!(3,0,nothing,nothing,nothing)===nothing
    @test !isfile(joinpath(OUTPUT,"diary-request-3.json"))
    @test occursin("不可逆な死亡を確定する判定はこの人間モデルにはない",CONFIGURED_API_SURVIVAL_LESSON)
end
@testset "Independent expression input fields" begin
    fields=configured_api_input_fields()
    @test fields.speech.available
    @test fields.speech.available_with_continue
    @test fields.gesture.available_with_continue
    @test fields.gesture.choices==CONFIGURED_API_GESTURES
    @test fields.speech.empty_means=="沈黙"
    @test occursin("発言禁止ではない",CONFIGURED_API_INPUT_LESSON)
end
@testset "Transfer projection to E" begin
    observed=(text="",motion=nothing,appearances=String[],transfers=[(from_visible_ref="npc_a",to_visible_ref="npc_b",appearance="meal-form",quantity=1)])
    configured_api_public!("npc_e",observed,"object-transferred",999)
    @test CONFIGURED_API_HISTORY[end].transfers==observed.transfers
    @test occursin("形レ",configured_api_input(CONFIGURED_API_HISTORY[end]))
    @test !occursin("meal-form",configured_api_input(CONFIGURED_API_HISTORY[end]))
end
@testset "Reserve-zero stop preserves state" begin
    output=mktempdir();captured=Ref(false)
    capture=()->(captured[]=true;Dict(:sentinel=>17))
    @test !configured_api_check_stop!((reserve=.001,),1,capture;output)
    @test !captured[]
    @test_throws ConfiguredAPIReserveStop configured_api_check_stop!((reserve=0.,),2,capture;output)
    @test captured[]
    @test deserialize(joinpath(output,"reserve-zero-state.bin")).state[:sentinel]==17
    @test JSON3.read(read(joinpath(output,"stopped.json"),String)).biological_death==false
end
