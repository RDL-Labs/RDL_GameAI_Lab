include("camp_trade_calls_checks.jl")
open_exchanges=0;open_proposals=0
@testset "payment undecided is discussion, not consent" begin
 for seed in 1:16
  f=camp_fixture(seed);a,b,c=f.ids
  f.foods.personal[a].=0;f.foods.personal[a][1]=8
  f.foods.personal[b].=0;f.foods.personal[b][7]=8
  event=camp_event(f);@test event["kind"]==7
  empty!(event["offered"])
  before=deepcopy(f.foods.personal)
  @test LW.configured_camp_trade_interest(event,f.states[b],f.maps[b],f.w.bodies[b],nothing,f.foods.personal[b],1)===nothing
  LW.configured_camp_trade_tick!(f.states,f.maps,f.w,f.foods,nothing,nothing,1_000_000,a->true,a->false,a->false;open_terms=true)
  @test f.states[b]["camp_trade"]["replied"]==1
  @test f.foods.personal==before
  @test f.states[b]["camp_trade"]["meeting"]["kind"]===nothing
  @test !LW.configured_camp_trade_busy(f.states[c])
  view=LW.configured_camp_trade_view(f.states[a],LW.item_visible(f.items,f.w,(0.,0.),a,0.,2_000_000;foods=f.foods),2_000_000)
  @test !haskey(view,"observed_food_stocks")
  plan=LW.configured_camp_trade_plan!(f.states[a],view,f.w.bodies[a],nothing,f.foods.personal[a],2_000_000;map=f.maps[a])
  plan===nothing && continue
  global open_proposals+=1
  receipt=LW.item_execute!(f.items,f.foods,f.w,f.stores,(0.,0.),a,"open:$seed","item_offer",2_000_000;
    target=b,give_items=plan["give_items"],want_items=plan["want_items"],give_food=plan["give_food"],want_food=plan["want_food"])
  LW.item_social_executed!(f.states[a],plan,receipt)
  @test receipt["status"]=="offered"
  @test f.foods.personal==before
  reply=LW.item_visible(f.items,f.w,(0.,0.),b,0.,3_000_000;foods=f.foods)
  response=LW.configured_camp_trade_plan!(f.states[b],reply,f.w.bodies[b],nothing,f.foods.personal[b],3_000_000;map=f.maps[b])
  response===nothing && continue
  outcome=LW.item_execute!(f.items,f.foods,f.w,f.stores,(0.,0.),b,"answer:$seed",response["action"],3_000_000;offer_id=response["offer_id"],
    give_items=get(response,"give_items",Int[]),want_items=get(response,"want_items",Int[]),give_food=get(response,"give_food",zeros(Int,8)),want_food=get(response,"want_food",zeros(Int,8)))
  if outcome["status"]=="exchanged"
   global open_exchanges+=1
   @test sum(sum(v) for v in values(f.foods.personal))==16
   @test f.foods.personal[a][7]>0 && f.foods.personal[b][1]>0
  end
 end
 @test open_proposals>0
 @test open_exchanges>0
 println(JSON3.write((open_proposals=open_proposals,open_exchanges=open_exchanges,seeds=16)))
end
@testset "expiry changes same negotiated terms" begin
 body=LW.RDLBody.Body(10.,0.,95.,0.);gut=LW.RDLBody.Digestion();day=17_280_000_000
 map=D("food_clock"=>(now=day-60_000_000,day_us=day))
 forecast=LW.food_expiry_forecast(map,body,gut)
 before=zeros(Int,8);before[7]=6
 after=copy(before);after[7]-=1;after[3]+=1
 security=LW.food_security_state();security["required"]=1.;security["expiry"]=forecast
 near=LW.trade_valuation_context(body,gut,security,D(),nothing)
 ample=deepcopy(near);ample["expiry"]["capacity"]=100.
 imminent=LW.trade_compound_gradient(before,after,-.1,near)
 usable=LW.trade_compound_gradient(before,after,-.1,ample)
 @test imminent["waste_relief"]>usable["waste_relief"]
 @test imminent["total"]>usable["total"]
 @test imminent["total"]>0 && usable["total"]<0
 println(JSON3.write((expiry_case=imminent,usable_case=usable)))
end
