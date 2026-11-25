using Test, JSON3, Serialization
const fixture_file=normpath(joinpath(@__DIR__,"../portable_items/checks.jl"))
include_string(Main,first(split(read(fixture_file,String),"@testset")),fixture_file)
function investment_case(enabled,strength;stock=20)
 f=item_fixture(objects=Any[],food_counts=[[stock,0,0,0],[0,0,0,20],[0,0,0,0]],scene=(configured_negotiation=true,))
 item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,give_food=[0,0,0,1],want_food=[1,0,0,0])
 relation=LW.social_relations_state(ITEM_A;relational=true);relation["trade_relationship_investment"]=enabled
 m=LW.trade_investment_peer!(relation,ITEM_B);m["strength"]=strength
 state=LW.incidental_item_state(ITEM_A,33)
 plan=LW.item_social_plan!(state,item_view(f,ITEM_A;now=1,open_stores=false),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;relation)
 (f=f,relation=relation,state=state,plan=plan,record=last(relation["gradient_maps"]["records"]))
end
@testset "LW relationship investment opt-in" begin
 off=investment_case(false,0.);off2=investment_case(false,.3)
 @test off.plan==off2.plan
 @test off.record==off2.record
 positive=investment_case(true,.3);negative=investment_case(true,-.3)
 acceptance(c)=filter(r->r["action"]=="item_accept",c.record["candidates"])
 @test !isempty(acceptance(positive))
 @test isempty(acceptance(negative)) || first(acceptance(positive))["probability"]>first(acceptance(negative))["probability"]
 row=first(acceptance(positive));@test row["compound_gradient"]["investment"]>0
 @test row["compound_gradient"]["relationship"]==0
 @test row["components"]["relation"]==0
 r=positive.relation;m=LW.trade_investment_peer!(r,ITEM_B)
 @test m["pending"]===nothing # candidate generation isn't an investment receipt
 forecast=LW.trade_investment_forecast(r,ITEM_B)
 @test LW.trade_investment_register!(r,ITEM_B,"original",1,forecast)
 @test !LW.trade_investment_register!(r,ITEM_B,"overwrite",2,forecast)
 @test !LW.trade_investment_observe!(r,LW.D("channel"=>"trade_response","outcome"=>"exchanged","other"=>ITEM_B,"us"=>3,"source"=>"own"))
 @test !LW.trade_investment_observe!(r,LW.D("channel"=>"trade_offer","outcome"=>"expired","other"=>ITEM_B,"us"=>3,"source"=>"unknown"))
 @test LW.social_relation_event!(r,ITEM_B,"trade_offer","later",4;outcome="declined")
 @test m["pending"]===nothing && LW.trade_investment_h(m)<0
 @test !LW.social_relation_event!(r,ITEM_B,"trade_offer","later",4;outcome="declined")
 @test length(m["records"])==1
 initial=m["strength"];LW.trade_investment_sleep!(r,1);@test m["strength"]<initial
 after=m["strength"];LW.trade_investment_sleep!(r,1);@test m["strength"]==after
 @test LW.trade_investment_h(m)==0
 io=IOBuffer();serialize(io,r);seekstart(io);restored=deserialize(io)
 @test LW.trade_investment_forecast(restored,ITEM_B)==LW.trade_investment_forecast(r,ITEM_B)
 # Predicted future benefit is excluded from today's material outcome.
 valuation=LW.trade_valuation_context(positive.f.w.bodies[ITEM_A],nothing,nothing,LW.D(),nothing)
 valuation["investment"]=forecast;valuation["relationship"]=0.
 before=positive.f.foods.personal[ITEM_A];afterstock=copy(before);afterstock[1]-=1;afterstock[4]+=1
 expected=LW.trade_compound_gradient(before,afterstock,.1,valuation)
 actual=LW.trade_compound_gradient(before,afterstock,.1,valuation;realized=true)
 @test expected["total"]-actual["total"]≈expected["investment"]
 @test actual["investment"]==0
 item_checks(positive.f)
end
@testset "executed exchange registers delayed forecast" begin
 c=investment_case(true,.3)
 @test c.plan["action"]=="item_accept"
 receipt=item_act(c.f,ITEM_A,"item_accept",1;offer_id=c.plan["offer_id"])
 @test receipt["status"]=="exchanged"
 @test LW.item_social_executed!(c.state,c.plan,receipt;relation=c.relation)
 m=LW.trade_investment_peer!(c.relation,ITEM_B)
 @test m["pending"]!==nothing
 @test LW.trade_investment_h(m)==0 && isempty(m["records"])
 @test !LW.item_social_executed!(c.state,c.plan,receipt;relation=c.relation)
 item_checks(c.f)
 println("selected positive action=",c.plan["action"],"; delayed prediction registered")
end
@testset "existing observed history seeds response forecast" begin
 s=LW.social_relations_state(ITEM_A;relational=true);s["trade_relationship_investment"]=true
 for i in 1:4;LW.social_relation_event!(s,ITEM_B,"trade_offer","past:$i",i;outcome="exchanged",value=1.);end
 # Observe hook does not create a forecast until a candidate requests one.
 fresh=LW.social_relations_state(ITEM_A;relational=true)
 for i in 1:4;LW.social_relation_event!(fresh,ITEM_B,"trade_offer","past:$i",i;outcome="exchanged",value=1.);end
 fresh["trade_relationship_investment"]=true
 @test LW.trade_investment_forecast(fresh,ITEM_B)["probability"]≈.75
end
@testset "neutral evidence survives sleep" begin
 s=LW.social_relations_state(ITEM_A;relational=true);s["trade_relationship_investment"]=true
 for i in 1:2
  LW.trade_investment_register!(s,ITEM_B,"gave:$i",i*10,LW.trade_investment_forecast(s,ITEM_B))
  LW.social_relation_event!(s,ITEM_B,"aid_received","response:$i",i*10+1;outcome="given",value=1.)
  LW.trade_investment_sleep!(s,i)
 end
 @test LW.trade_investment_forecast(s,ITEM_B)["probability"]>.5
end
