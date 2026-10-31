include("checks.jl")
function trade_relation(actor,other,distress)
    r=LW.social_relations_state(actor;relational=true)
    r["social_view"]=Dict("peers"=>[Dict("ref"=>other,"expression"=>(distress=distress,fear=0.))])
    r
end

@testset "shortage is a component, not admission" begin
    b=LW.Body(10.,0.,90.,0.)
    v=LW.trade_valuation_context(b,nothing,nothing,Dict(),nothing)
    calm=LW.trade_compound_gradient([10,0,0,0],[6,0,0,0],-.3,v)
    helping=LW.trade_compound_gradient([10,0,0,0],[6,0,0,0],-.3,merge(v,Dict("distress"=>1.)))
    @test calm["need_before"]==calm["need_after"]==0
    @test calm["total"]<0<helping["total"]
    @test helping["material"]<0 && helping["aid"]>0
    scarce=LW.trade_compound_gradient([10,0,0,0],[6,0,0,0],-.3,merge(v,Dict("required"=>10.,"distress"=>1.)))
    @test scarce["security"]<0 && scarce["total"]<0
    @test LW.trade_food_need(b,nothing,[10,0,0,0])==0
    @test LW.trade_food_relief(b,nothing,[10,0,0,0],[4,0,0,0],zeros(Int,4))==0
    @test helping["total"]≈sum(helping[k] for k in ("material","security","aid","relationship","cost"))
    nofood=LW.trade_valuation_context(b,nothing,nothing,Dict(),nothing;food_enabled=false)
    @test LW.trade_compound_gradient(nothing,nothing,.2,nofood)["need_before"]==0
end

@testset "stocked actors may propose; consideration is still throttled" begin
    f=item_fixture(food_counts=[[0,0,20,0],[20,0,0,0],[0,0,0,0]])
    f.w.positions[ITEM_C]=(100.,100.)
    offered=0
    for seed in 1:32
        t=LW.food_trade_state(seed)
        v=LW.food_exchange_view(t["world"],f.foods,f.w,ITEM_HOME,ITEM_A,0;open_stores=true)
        p=LW.food_trade_plan!(t,ITEM_A,v,f.w.bodies[ITEM_A],nothing,0)
        p===nothing && continue
        offered+=1
        @test p["compound_gradient"]["need_before"]==0
        @test p["compound_gradient"]["need_after"]==0
        @test LW.food_trade_plan!(t,ITEM_A,v,f.w.bodies[ITEM_A],nothing,1)===nothing
    end
    @test offered>0
end

@testset "food barter accepts observed aid despite material loss" begin
    accepted=false
    for seed in 1:32
        f=item_fixture(food_counts=[[20,0,20,0],[0,0,20,0],[0,0,0,0]])
        t=LW.food_trade_state(seed;relational=true)
        o=LW.food_exchange_execute!(t["world"],f.foods,f.w,f.stores,ITEM_HOME,ITEM_B,"offer","trade_offer",0;
            target=ITEM_A,give_kind=3,give_count=1,want_kind=1,want_count=3)
        v=LW.food_exchange_view(t["world"],f.foods,f.w,ITEM_HOME,ITEM_A,1;open_stores=true)
        calm=trade_relation(ITEM_A,ITEM_B,0.)
        quiet=LW.food_trade_plan!(LW.food_trade_state(seed;relational=true),ITEM_A,v,f.w.bodies[ITEM_A],nothing,1;relation=calm)
        @test quiet["action"]=="trade_decline"
        scarce=trade_relation(ITEM_A,ITEM_B,1.);scarce["food_security"]=Dict("required"=>45.)
        cautious=LW.food_trade_plan!(LW.food_trade_state(seed;relational=true),ITEM_A,v,f.w.bodies[ITEM_A],nothing,1;relation=scarce)
        @test cautious["action"]=="trade_decline"
        relation=trade_relation(ITEM_A,ITEM_B,1.)
        p=LW.food_trade_plan!(t,ITEM_A,v,f.w.bodies[ITEM_A],nothing,1;relation)
        p["action"]=="trade_accept" || continue
        @test p["compound_gradient"]["material"]<0 && p["compound_gradient"]["aid"]>0
        @test p["trade_gain"]>0 && p["compound_gradient"]["need_before"]==0
        receipt=LW.food_exchange_execute!(t["world"],f.foods,f.w,f.stores,ITEM_HOME,ITEM_A,"accept","trade_accept",1;offer_id=o["offer_id"])
        @test receipt["status"]=="exchanged"
        @test LW.food_trade_actual(p["trade_weights"],receipt;valuation=p["valuation"])≈p["trade_gain"]
        @test LW.food_trade_actual(p["trade_weights"],Dict("status"=>"declined");valuation=p["valuation"])==0
        LW.food_trade_executed!(t,ITEM_A,p,receipt;relation)
        @test last(t["minds"][ITEM_A]["response"].events).reward>0
        @test any(c->haskey(c,"compound_gradient"),last(relation["gradient_maps"]["records"])["candidates"])
        @test item_checks(f)===nothing
        println("food aid components ",JSON3.write(p["compound_gradient"]))
        accepted=true;break
    end
    @test accepted
end

@testset "mixed aid barter retains the same evaluation at settlement" begin
    accepted=false
    for seed in 1:32
        f=item_fixture(objects=[placed_item(2,2;owner=ITEM_B,location="held")],food_counts=[[10,0,0,0],[0,0,0,0],[0,0,0,0]])
        o=item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,give_items=[2],want_food=[4,0,0,0])
        v=LW.item_visible(f.s,f.w,ITEM_HOME,ITEM_A,0.,1;open_stores=true,foods=f.foods)
        calm=trade_relation(ITEM_A,ITEM_B,0.)
        p0=LW.item_social_plan!(LW.incidental_item_state(ITEM_A,seed),v,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;relation=calm)
        @test p0["action"]!="item_accept"
        state=LW.incidental_item_state(ITEM_A,seed);relation=trade_relation(ITEM_A,ITEM_B,1.)
        p=LW.item_social_plan!(state,v,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;relation)
        p["action"]=="item_accept" || continue
        @test p["gain"]<0 && p["subjective_gain"]>0
        @test p["necessity"]["relief"]==0 && p["necessity"]["required"]===false
        relation["social_view"]=nothing
        receipt=item_act(f,ITEM_A,"item_accept",1;offer_id=o["offer_id"])
        @test receipt["status"]=="exchanged"
        @test LW.item_social_actual(p,receipt)≈p["subjective_gain"]
        @test LW.item_social_actual(p,Dict("status"=>"declined"))==0
        @test LW.item_social_executed!(state,p,receipt;relation)
        @test !LW.item_social_executed!(state,p,receipt;relation)
        @test last(state["social"]["records"])["actual"]>0
        @test item_checks(f)===nothing
        println("mixed aid components ",JSON3.write(p["compound_gradient"]))
        accepted=true;break
    end
    @test accepted
end
