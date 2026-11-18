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
    @test projected.give==Dict("果実"=>1)
    @test projected.receive==Dict("塩焼き魚"=>2)
    @test !occursin("PRIVATE_SENTINEL",JSON3.write(projected))
    @test !occursin("expected",JSON3.write(projected))
    configured_api_meal!("npc_a",1,.8,1,80.,80.)
    @test isempty(CONFIGURED_API_HISTORY)
    configured_api_meal!("npc_e",1,.8,1,80.,80.)
    @test length(CONFIGURED_API_HISTORY)==1
    configured_api_public!("npc_e",nothing,nothing,2)
    @test length(CONFIGURED_API_HISTORY)==1
    configured_api_public!("npc_a",(text="秘密",motion=nothing,appearances=[]),nothing,2)
    @test length(CONFIGURED_API_HISTORY)==1
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
