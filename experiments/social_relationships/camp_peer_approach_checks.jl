using Test
include("../../src/lw/LW.jl")
@testset "observed meeting peer becomes movement target" begin
    state=LW.incidental_item_state("npc_a",1)
    LW.configured_camp_trade_state!(state)["meeting"]=LW.D("peer"=>"npc_b")
    rows=[LW.D("ref"=>string(i-1),"cost"=>1.,"clear"=>true) for i in eachindex(LW.ANGLES)]
    sight=LW.D("peers"=>[LW.D("ref"=>"npc_b","angle"=>90.,"distance"=>1.625,"contact"=>false)])
    plan=LW.configured_camp_trade_approach(state,(0.,0.),(0.,0.),0.,rows;sight)
    @test plan["method"]=="camp_trade_peer_approach"
    @test LW.ANGLES[plan["direction"]+1]==90
    @test LW.configured_camp_trade_approach(state,(0.,0.),(0.,0.),0.,rows)===nothing
    @test LW.configured_camp_trade_approach(state,(0.,0.),(0.,0.),0.,rows;sight=LW.D("peers"=>Any[]))===nothing
    sight["peers"][1]["contact"]=true
    @test LW.configured_camp_trade_approach(state,(0.,0.),(0.,0.),0.,rows;sight)===nothing
    sight["peers"][1]["contact"]=false
    @test LW.configured_camp_trade_approach(state,(0.,0.),(0.,0.),0.,Any[];sight)["action"]=="scan"
end
