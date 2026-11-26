include("../portable_items/checks.jl")
const U=LW
@testset "reachable food replaces additive salt value" begin
 m=U.D("trade_use_outlook"=>true)
 for (k,v) in ((1,1.),(7,1.5),(8,3.));U.food_remember_taste!(m,k,2,v,0);end
 body=U.RDLBody.Body(10.,0.,90.,0.)
 kitchen=(foods=nothing,actor=ITEM_A,facilities=[(x=0.,z=0.,work_radius=2.,processing_kinds=[5])],position=(0.,0.),processing=true)
 model=U.trade_use_model(m,kitchen,body,nothing,Set([1,2]))
 stock=[1,0,0,0,1,0,0,0];weights=zeros(8)
 initial=deepcopy(stock)
 @test U.trade_use_delta(stock,stock,0,1,weights,model).correction>0
 @test U.trade_use_delta(stock,stock,1,2,weights,model).correction==0
 @test U.trade_use_delta(stock,stock,1,1,weights,model).correction==0
 nofish=copy(stock);nofish[5]=0
 @test U.trade_use_delta(nofish,nofish,0,1,weights,model).correction==0
 nofire=U.trade_use_model(m,nothing,body,nothing,Set([1,2]))
 @test U.trade_use_delta(stock,stock,0,1,weights,nofire).correction==0
 @test U.trade_use_outlook(stock,1,model).goal==8
 large=deepcopy(model);for r in large["recipes"];r["salt"]==1 && (r["salt"]=2);end
 @test U.trade_use_delta(stock,stock,1,2,weights,large).correction>0
 @test stock==initial
 @test item_saved_copy(model)==model
end
@testset "connected salt negotiation and receipt" begin
 f=item_fixture(objects=[placed_item(1,4;owner=ITEM_A,location="held"),placed_item(2,4;owner=ITEM_B,location="held")],food_counts=[[2,0,0,0,1,0,0,0],zeros(Int,8),zeros(Int,8)])
 m=U.D("trade_use_outlook"=>true);U.configured_observe_salt_sample!(m,f.s)
 kitchen=(foods=f.foods,actor=ITEM_A,facilities=[(x=0.,z=0.,work_radius=2.,processing_kinds=[5])],position=(0.,0.),processing=true)
 # Identical perceived holdings, including identical quantities, do not improve a goal.
 offer=item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,give_items=[2],want_items=[1])
 f.s["offers"][offer["offer_id"]]["round"]=8
 for seed in 1:8
  state=U.incidental_item_state(ITEM_A,seed)
  plan=U.item_social_plan!(state,item_view(f,ITEM_A;now=1,open_stores=true),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;map=m,kitchen)
  @test plan["action"]=="item_decline"
 end
 @test item_checks(f)===nothing
 # New fixture: buyer lacks salt, has fish, remembers liking salted fish.
 f=item_fixture(objects=[placed_item(2,4;owner=ITEM_B,location="held")],food_counts=[[2,0,0,0,1,0,0,0],zeros(Int,8),zeros(Int,8)])
 m=U.D("trade_use_outlook"=>true);U.configured_observe_salt_sample!(m,f.s)
 for (k,v) in ((1,.5),(7,.5),(8,4.));U.food_remember_taste!(m,k,2,v,0);end
 kitchen=merge(kitchen,(foods=f.foods,))
 offer=item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,give_items=[2],want_food=[1,0,0,0,0,0,0,0])
 accepted=nothing
 for seed in 1:32
  state=U.incidental_item_state(ITEM_A,seed)
  plan=U.item_social_plan!(state,item_view(f,ITEM_A;now=1,open_stores=true),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;map=m,kitchen)
  if plan["action"]=="item_accept";accepted=plan;break;end
 end
 @test accepted!==nothing
 if accepted!==nothing
  @test accepted["use_transition"].after.goal==8
  receipt=item_act(f,ITEM_A,"item_accept",2;offer_id=offer["offer_id"])
  @test receipt["status"]=="exchanged"
  @test U.item_social_actual(accepted,receipt)≈accepted["subjective_gain"]
  @test item_checks(f)===nothing
 end
end
@testset "ordinary proposals cannot create a pointless salt swap" begin
 f=item_fixture(objects=[placed_item(1,4;owner=ITEM_A,location="held"),placed_item(2,4;owner=ITEM_B,location="held")],food_counts=[zeros(Int,8),zeros(Int,8),zeros(Int,8)])
 m=U.D("trade_use_outlook"=>true);U.configured_observe_salt_sample!(m,f.s)
 for seed in 1:8
  state=U.incidental_item_state(ITEM_A,seed)
  plan=U.item_social_plan!(state,item_view(f,ITEM_A;now=1,open_stores=true),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;map=m)
  @test plan===nothing
 end
 @test item_checks(f)===nothing
end
