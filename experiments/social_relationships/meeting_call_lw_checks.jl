# Run the existing short full-LW call/restart fixture with name-call wiring on.
using JSON3
const call_roster=JSON3.read(read(joinpath(@__DIR__,"../trade_living/call_input.json"),String)).scene.peer_identity_roster
const source_test=joinpath(@__DIR__,"camp_trade_lw_checks.jl")
test_code=read(source_test,String)
test_code=replace(test_code,"personal_house_idle=true,"=>"personal_house_idle=true,social_relationships=true,")
test_code=replace(test_code,"camp_trade_calls=true,"=>"camp_trade_calls=true,meeting_name_calls=true,peer_identity_roster=call_roster,")
test_code=replace(test_code,"channels=result[\"incidental_items\"]"=>"channels=result[\"incidental_items\"]; @test any(e->get(e,\"method\",nothing)==\"meeting_name_call\",result[\"events\"]); @test any(e->get(e,\"method\",nothing)==\"identity_answer_turn\",result[\"events\"])")
include_string(Main,test_code,source_test)
