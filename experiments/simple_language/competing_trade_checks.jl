include("../portable_items/checks.jl")
include("reply_trade.jl")
# Fixed local fixture: known, visible partners and explicitly scripted proposals.
# Only the recipient's comparison/consent is autonomous. No normal-life wiring.
const COMPETING_TRADE=(seeds=32,decision_us=3_000_000,original_units=1,interrupt_units=3)
function competing_fixture()
 f=item_fixture(objects=Any[],food_counts=[[0,0,0,0,0,0,0,1],[20,0,0,0,0,0,0,0],[20,0,0,0,0,0,0,0]],scene=(configured_negotiation=true,))
 empty!(f.w.obstacles)
 f.w.positions[ITEM_A]=(0.,0.);f.w.positions[ITEM_B]=(-.5,.8);f.w.positions[ITEM_C]=(.5,.8)
 offers=Dict{String,String}()
 for (i,peer) in enumerate((ITEM_B,ITEM_C))
  give=zeros(Int,8);give[1]=peer==ITEM_B ? COMPETING_TRADE.original_units : COMPETING_TRADE.interrupt_units
  want=zeros(Int,8);want[8]=1
  receipt=item_act(f,peer,"item_offer",i*1_000_000;target=ITEM_A,give_food=give,want_food=want)
  @test receipt["status"]=="offered"
  offers[peer]=receipt["offer_id"]
 end
 f,offers
end
results=Any[]
@testset "competing observed proposals" begin
 for compare in (false,true),seed in 1:COMPETING_TRADE.seeds
  f,offers=competing_fixture()
  state=LW.incidental_item_state(ITEM_A,seed)
  relation=LW.social_relations_state(ITEM_A;relational=true)
  observed=item_view(f,ITEM_A;now=COMPETING_TRADE.decision_us,open_stores=true)
  @test length(observed["incoming"])==2
  plan=LW.item_social_plan!(state,observed,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],COMPETING_TRADE.decision_us;relation,compare_incoming=compare)
  @test plan!==nothing
  receipt=reply_trade_execute!(f,ITEM_A,state,relation,plan,COMPETING_TRADE.decision_us)
  @test item_checks(f)===nothing
  final_status=receipt["status"]
  if final_status=="offered"
   peer=plan["partner"];peer_state=LW.incidental_item_state(peer,seed)
   peer_view=item_view(f,peer;now=4_000_000,yaw=180.,open_stores=true)
   peer_plan=LW.item_social_plan!(peer_state,peer_view,f.w.bodies[peer],nothing,f.foods.personal[peer],4_000_000)
   if peer_plan!==nothing
    final_status=reply_trade_execute!(f,peer,peer_state,nothing,peer_plan,4_000_000)["status"]
   end
  end
  @test item_checks(f)===nothing
  push!(results,(compare=compare,seed=seed,action=plan["action"],partner=plan["partner"],status=receipt["status"],final_status=final_status,priority=plan["priority"]))
 end
 # World ownership is authoritative even when both promises wanted the same fish.
 f,offers=competing_fixture()
 @test item_act(f,ITEM_A,"item_accept",3_000_000;offer_id=offers[ITEM_C])["status"]=="exchanged"
 @test item_act(f,ITEM_A,"item_accept",4_000_000;offer_id=offers[ITEM_B])["status"]=="unavailable"
 @test item_checks(f)===nothing
 @test all(r->r.compare || r.partner==ITEM_B,results)
 @test any(r->r.compare && r.partner==ITEM_C,results)
end
summary=[(compare=compare,original=count(r->r.compare==compare && r.partner==ITEM_B,results),
 interruption=count(r->r.compare==compare && r.partner==ITEM_C,results),
 exchanged=count(r->r.compare==compare && r.final_status=="exchanged",results),
 countered=count(r->r.compare==compare && r.action=="item_counter",results)) for compare in (false,true)]
write(joinpath(@__DIR__,"competing_trade_result.json"),JSON3.write((summary=summary,trials=results)))
println(JSON3.write(summary))
