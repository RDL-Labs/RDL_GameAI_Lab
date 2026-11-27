include("camp_trade_calls_checks.jl")
Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/camp_surplus_local.jl"))
sell_proposals=0;sell_exchanges=0;sell_paid=0;sell_free=0
@testset "surplus sale enters ordinary negotiation" begin
 for seed in 1:16
  f=camp_fixture(seed);seller,buyer,other=f.ids
  body=f.w.bodies[seller];gut=LW.RDLBody.Digestion();day=17_280_000_000
  f.maps[seller]["food_clock"]=(now=day-60_000_000,day_us=day)
  security=LW.food_security_state();security["required"]=1.
  security["expiry"]=LW.food_expiry_forecast(f.maps[seller],body,gut)
  f.maps[seller]["food_security"]=security
  rows=LW.configured_surplus_candidates(f.maps[seller],body,gut,f.foods.personal[seller])
  @test length(rows)==1 && rows[1]["kind"]==7
  if seed==1
   println(JSON3.write((sale_candidate=rows[1],forecast=security["expiry"])))
  end
  saved=deepcopy(security["expiry"]);security["expiry"]["capacity"]=100.
  @test isempty(LW.configured_surplus_candidates(f.maps[seller],body,gut,f.foods.personal[seller]))
  security["expiry"]=saved
  # A familiar fish may still be unwanted when the listener also expects waste.
  f.maps[other]["food_security"]=deepcopy(security)
  f.foods.personal[other][7]=8
  @test LW.configured_surplus_reply!(seller,other,rows[1],f.states,f.maps,f.w,f.foods,1_000_000;gut)===nothing
  f.foods.personal[other][7]=0
  @test !LW.configured_camp_trade_busy(f.states[seller])
  before=deepcopy(f.foods.personal)
  # No knowledge/recognition: hearing does not invent a taste or buyer.
  empty!(f.maps[other])
  @test LW.configured_surplus_reply!(seller,other,rows[1],f.states,f.maps,f.w,f.foods,1_000_000)===nothing
  @test !LW.configured_camp_trade_busy(f.states[seller])
  @test LW.configured_surplus_reply!(seller,buyer,rows[1],f.states,f.maps,f.w,f.foods,1_000_000)!==nothing
  @test f.foods.personal==before
  view=LW.configured_camp_trade_view(f.states[buyer],LW.item_visible(f.items,f.w,(0.,0.),buyer,0.,2_000_000;foods=f.foods),2_000_000)
  @test !haskey(view,"observed_food_stocks")
  plan=LW.configured_camp_trade_plan!(f.states[buyer],view,f.w.bodies[buyer],nothing,f.foods.personal[buyer],2_000_000;map=f.maps[buyer])
  plan===nothing && continue
  global sell_proposals+=1
  receipt=LW.item_execute!(f.items,f.foods,f.w,f.stores,(0.,0.),buyer,"sell:$seed","item_offer",2_000_000;
    target=seller,give_items=plan["give_items"],want_items=plan["want_items"],give_food=plan["give_food"],want_food=plan["want_food"])
  LW.item_social_executed!(f.states[buyer],plan,receipt)
  @test receipt["status"]=="offered"
  @test f.foods.personal==before
  reply=LW.item_visible(f.items,f.w,(0.,0.),seller,0.,3_000_000;foods=f.foods)
  response=LW.configured_camp_trade_plan!(f.states[seller],reply,body,gut,f.foods.personal[seller],3_000_000;map=f.maps[seller])
  response===nothing && continue
  outcome=LW.item_execute!(f.items,f.foods,f.w,f.stores,(0.,0.),seller,"sell-answer:$seed",response["action"],3_000_000;offer_id=response["offer_id"],
    give_items=get(response,"give_items",Int[]),want_items=get(response,"want_items",Int[]),give_food=get(response,"give_food",zeros(Int,8)),want_food=get(response,"want_food",zeros(Int,8)))
  if outcome["status"]=="exchanged"
   global sell_exchanges+=1
   @test sum(sum(v) for v in values(f.foods.personal))==16
   @test f.foods.personal[buyer][7]>0
   if f.foods.personal[seller][1]>0;global sell_paid+=1;else;global sell_free+=1;end
  end
 end
 @test sell_proposals>0
 @test sell_exchanges>0
 println(JSON3.write((sell_proposals=sell_proposals,sell_exchanges=sell_exchanges,paid=sell_paid,free=sell_free,seeds=16)))
end


@testset "normal tick delivers sale after call, then expires unmatched" begin
 f=camp_fixture();a,b,c=f.ids
 row=D("kind"=>7,"quantity"=>1,"gradient"=>D("total"=>1.))
 event=D("direction"=>"sell","caller"=>a,"kind"=>7,"row"=>row,"created_us"=>0,"expires_us"=>128_000_000,"addressee"=>nothing,"heard"=>Set{String}(),"replies"=>Any[])
 f.states[a]["camp_trade"]=LW.configured_camp_trade_state!(f.states[a]);f.states[a]["camp_trade"]["outgoing"]=event
 before=deepcopy(f.foods.personal)
 camp_tick(f,0);@test f.states[b]["camp_trade"]["meeting"]===nothing
 camp_tick(f,1_000_000)
 @test f.states[b]["camp_trade"]["meeting"]["initiator"]
 @test f.states[a]["camp_trade"]["outgoing"]===nothing
 @test f.foods.personal==before
 g=camp_fixture();empty!(g.maps[b]);empty!(g.maps[c])
 LW.configured_camp_trade_state!(g.states[a])["outgoing"]=deepcopy(event)
 empty!(g.states[a]["camp_trade"]["outgoing"]["heard"])
 camp_tick(g,1_000_000);@test g.states[a]["camp_trade"]["meeting"]===nothing
 camp_tick(g,128_000_000);@test g.states[a]["camp_trade"]["outgoing"]===nothing
 @test g.states[a]["camp_trade"]["expired"]==1
end

@testset "buy sell hold selection enters call lifecycle" begin
 modes=Set{String}()
 for seed in 1:64
  f=camp_fixture(seed);a=first(f.ids)
  security=LW.food_security_state();security["required"]=1.
  security["expiry"]=LW.food_expiry_forecast(f.maps[a],f.w.bodies[a],nothing;now=17_220_000_000)
  f.maps[a]["food_security"]=security
  event=LW.configured_camp_trade_call!(f.states[a],f.maps[a],f.w.bodies[a],nothing,f.foods.personal[a],0,17_280_000_000;surplus_calls=true)
  push!(modes,event===nothing ? "hold" : get(event,"direction","buy"))
  @test f.states[a]["camp_trade"]["last_day"]==0
  @test LW.configured_camp_trade_call!(f.states[a],f.maps[a],f.w.bodies[a],nothing,f.foods.personal[a],1,17_280_000_000;surplus_calls=true)===nothing
 end
 @test "sell" in modes
 println(JSON3.write((selected_modes=collect(modes),seeds=64)))
end
