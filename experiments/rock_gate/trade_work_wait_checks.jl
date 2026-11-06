using Test
include("../../src/lw/LW.jl")
const D=LW.D
@testset "defer work-bound offers without fabricating outcomes" begin
 state=LW.incidental_item_state("npc_a",1);mind=LW.item_social_state!(state)
 loop=mind["offer"];h=loop.H
 p=LW.choose_method!(loop,[D("method"=>"offer","priority"=>1.,"question"=>"subjective_possession_value","action"=>"item_offer","target"=>"npc_b")],"wait-test")
 p["source"]="wait-test"
 workers=LW.configured_trade_workers(D("npc_b"=>("exploration","home","process_food",nothing,"processing"),"npc_c"=>("night","home","process_food",nothing,"processed"),"npc_d"=>("night","sleep")))
 @test workers==Set(["npc_b"])
 wait=LW.configured_trade_wait_intercept!(state,p,workers,10,1000)
 @test wait["action"]=="rest" && wait["configured_rule"]=="wait_before_trade_offer"
 @test loop.trial===nothing && loop.H==h
 @test mind["pending"]===nothing && mind["proposed"]==0
 @test LW.configured_trade_wait_poll!(state,workers,["npc_b"],11,1000)["action"]=="rest"
 mind["next_us"]=100
 @test LW.configured_trade_wait_poll!(state,Set{String}(),["npc_b"],12,1000)===nothing
 @test state["configured_work_wait"]["target"]===nothing && mind["next_us"]==0
 @test state["configured_work_wait"]["released"]==1
 for mode in (:depart,:incoming,:night,:nextday)
  q=state["configured_work_wait"];q["target"]="npc_b";q["day"]=0
  @test LW.configured_trade_wait_poll!(state,workers,mode==:depart ? String[] : ["npc_b"],mode==:nextday ? 1000 : 15,1000;eligible=mode!=:night,incoming=mode==:incoming)===nothing
  @test q["target"]===nothing
 end
 for action in ("item_accept","item_counter","item_decline")
  p=D("action"=>action,"target"=>"npc_b")
  @test LW.configured_trade_wait_intercept!(state,p,workers,20,1000)===p
 end
 @test LW.incidental_item_snapshot(state)["configured_work_wait"]["entries"]==1
end

@testset "reply wait and simultaneous departure" begin
 state=LW.incidental_item_state("npc_a",1);mind=LW.item_social_state!(state)
 w=LW.world(true);w.positions["npc_a"]=(0.,0.);w.positions["npc_b"]=(0.,0.)
 items=D("offers"=>D("o"=>D("proposer"=>"npc_a","target"=>"npc_b","expires_us"=>30)))
 @test LW.configured_trade_reply_wait(state,items,w,(0.,0.),"npc_a",1)["action"]=="rest"
 @test LW.configured_trade_reply_wait(state,items,w,(0.,0.),"npc_a",30)===nothing
 w.positions["npc_b"]=(100.,100.)
 @test LW.configured_trade_reply_wait(state,items,w,(0.,0.),"npc_a",1)===nothing
 p=LW.choose_method!(mind["offer"],[D("method"=>"offer","question"=>"subjective_possession_value","priority"=>1.,"action"=>"item_offer","target"=>"npc_b")],"departure")
 p["source"]="departure";p["purpose_family"]="home"
 p["trail_parent"]=(reserve=80.,H=2.)
 p["bundle_parent"]=D("actor"=>"npc_a","due"=>false,"H"=>2.)
 p["trail_trace"]=D("offer_only"=>true)
 plans=D("npc_a"=>p,"npc_b"=>D("action"=>"walk"))
 LW.configured_trade_departure_guard!(plans,D("npc_a"=>state),(),1,1000)
 @test plans["npc_a"]["configured_rule"]=="defer_trade_departing_partner"
 @test plans["npc_a"]["purpose_family"]=="home"
 @test plans["npc_a"]["trail_parent"]==p["trail_parent"]
 @test plans["npc_a"]["bundle_parent"]==p["bundle_parent"]
 @test !haskey(plans["npc_a"],"trail_trace")
 @test mind["offer"].trial===nothing && mind["pending"]===nothing
 @test state["configured_work_wait"]["departure_deferrals"]==1
end
