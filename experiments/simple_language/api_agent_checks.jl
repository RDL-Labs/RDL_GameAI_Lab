using JSON3,Test
const OUTPUT=mktempdir()
include("../../src/lw/configured_paths/api_trade_agent.jl")
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
