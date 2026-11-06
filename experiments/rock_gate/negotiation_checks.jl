using Test
include("../../src/lw/LW.jl")
const D=LW.D
@testset "negotiation: three adjustments, one outcome" begin
 w=LW.world(true)
 for a in LW.IDS;w.positions[a]=(0.,0.);w.inventory[a]=0;end
 entries=[D("id"=>i,"kind"=>1,"owner"=>a,"location"=>"held","x"=>0.,"z"=>0.) for (i,a) in enumerate(("npc_a","npc_b"))]
 s=LW.portable_items((portable_items=entries,configured_negotiation=true),w)
 stores=Dict(a=>0 for a in LW.IDS)
 act(a,action,t;kw...)=LW.item_execute!(s,nothing,w,stores,(0.,0.),a,"test:$t",action,t;kw...)
 first=act("npc_a","item_offer",0;target="npc_b",give_items=[1],want_items=[2]);id=first["offer_id"];root=id
 @test first["status"]=="offered"
 for round in 1:3
  a=isodd(round) ? "npc_b" : "npc_a";b=isodd(round) ? "npc_a" : "npc_b"
  give=a=="npc_a" ? [1] : [2];want=a=="npc_a" ? [2] : [1]
  reply=act(a,"item_counter",round;target=b,offer_id=id,give_items=give,want_items=want)
  @test reply["status"]=="offered"
  id=reply["offer_id"]
  @test s["offers"][id]["round"]==round && s["offers"][id]["root_id"]==root
 end
 bad=act("npc_a","item_counter",4;target="npc_b",offer_id=id,give_items=[1],want_items=[2])
 @test bad["reason"]=="counter_round_limit"
 @test haskey(s["offers"],id)
 @test act("npc_a","item_accept",5;offer_id=id)["status"]=="exchanged"
 counts=s["negotiations"]["counts"]
 @test counts==D("started"=>1,"adjusted"=>3,"mismatch"=>3,"agreed"=>1,"ended"=>0,"interrupted"=>0)
 @test isempty(s["offers"])
 @test LW.item_audit!(s,w)===nothing
 @test LW.item_snapshot(s)["negotiations"]["counts"]==counts
 @test LW.configured_negotiation_limit(false)==8
 @test LW.configured_negotiation_adjusting(true,[D("action"=>"item_counter")])
 @test !LW.configured_negotiation_adjusting(false,[D("action"=>"item_counter")])
 @test !LW.configured_negotiation_adjusting(true,[D("action"=>"item_accept")])
 offer=act("npc_a","item_offer",6;target="npc_b",give_items=[2],want_items=[1])
 @test act("npc_b","item_decline",7;offer_id=offer["offer_id"])["status"]=="declined"
 @test counts["ended"]==1 && counts["started"]==2
 offer=act("npc_a","item_offer",8;target="npc_b",give_items=[2],want_items=[1])
 LW.item_expire!(s,30_000_008)
 @test counts["interrupted"]==1 && counts["started"]==3
end
