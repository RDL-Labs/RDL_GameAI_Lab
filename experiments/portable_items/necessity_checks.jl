include("checks.jl")

@testset "shared near-term food necessity" begin
    b=LW.Body(10.,0.,90.,0.)
    @test LW.trade_food_need(b,nothing,nothing)==0
    @test LW.trade_food_need(b,nothing,[0,0,0,0])==1
    @test LW.trade_food_need(b,nothing,[1,0,0,0])==0
    @test LW.trade_food_need(b,nothing,[0,0,1,0])==0 # known processing alternative
    @test LW.trade_food_need(b,(gut=1.,),zeros(Int,4))==0
    hungry=LW.Body(10.,0.,30.,0.)
    @test LW.trade_food_need(hungry,(gut=.5,),[1,0,0,0])==1
    @test LW.trade_food_relief(hungry,nothing,[0,0,1,0],[0,0,1,0],[2,0,0,0])==1
    @test LW.trade_food_relief(hungry,nothing,[0,0,1,0],zeros(Int,4),zeros(Int,4))==0
end

@testset "stocked actor skips recall and choice without changing H or RNG" begin
    f=barter_fixture();s=LW.incidental_item_state(ITEM_A,7)
    m=LW.item_social_state!(s);before=LW.loop_snapshot(m["offer"]);rng=copy(m["offer"].rng)
    for now in (0,64_000_000)
        @test LW.item_social_plan!(s,item_view(f,ITEM_A;now),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],now)===nothing
    end
    @test LW.loop_snapshot(m["offer"])==before && m["offer"].rng==rng
    @test m["decisions"]==0 && m["candidates"]==0 && m["need_skipped"]==2
    @test !haskey(s,"exchange_relations")
    o=item_act(f,ITEM_B,"item_offer",1;target=ITEM_A,want_items=[1],give_food=[0,0,1,0])
    p=LW.item_social_plan!(s,item_view(f,ITEM_A;now=2),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],2)
    @test p["action"]=="item_decline" # incoming still handled, no counter
    result=item_act(f,ITEM_A,p["action"],2;offer_id=o["offer_id"])
    @test LW.item_social_executed!(s,p,result)
    @test item_checks(f)===nothing
end

@testset "needed food can be requested using an object; receipts survive gate" begin
    chosen=nothing
    for seed in 1:128
        f=item_fixture(objects=[placed_item(1,1;owner=ITEM_A,location="held"),placed_item(2,2;owner=ITEM_B,location="held")],
            food_counts=[[0,0,0,0],[4,0,0,0],[0,0,0,0]])
        s=LW.incidental_item_state(ITEM_A,seed)
        p=LW.item_social_plan!(s,item_view(f,ITEM_A),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],0)
        p===nothing && continue
        @test p["necessity"]["relief"]>0 && sum(p["want_food"])>sum(p["give_food"])
        @test !isempty(p["give_items"]) || !isempty(p["want_items"])
        if p["target"]==ITEM_B && p["give_items"]==[1] && isempty(p["want_items"]) && p["want_food"][1]>0 && sum(p["want_food"][2:4])==0
            chosen=(f,s,p);break
        end
    end
    @test chosen!==nothing
    if chosen!==nothing
        f,s,p=chosen
        receipt=item_act(f,ITEM_A,p["action"],0;target=p["target"],give_items=p["give_items"],want_items=p["want_items"],give_food=p["give_food"],want_food=p["want_food"])
        @test LW.item_social_executed!(s,p,receipt)
        # Explicit world fixture acceptance tests asynchronous credit, not the
        # claim that a stocked autonomous responder has a reason to consent.
        accepted=item_act(f,ITEM_B,"item_accept",1;offer_id=receipt["offer_id"])
        @test accepted["status"]=="exchanged"
        v=item_view(f,ITEM_A;now=2)
        LW.item_social_observe!(s,v)
        @test s["social"]["pending"]===nothing
        before=deepcopy(s["social"]["records"])
        LW.item_social_observe!(s,v)
        @test s["social"]["records"]==before
        @test LW.item_social_plan!(s,v,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],64_000_000)===nothing
        @test item_checks(f)===nothing
    end
end

@testset "food-only route shares necessity admission" begin
    f=barter_fixture();t=LW.food_trade_state(3)
    v=LW.food_exchange_view(t["world"],f.foods,f.w,ITEM_HOME,ITEM_A,0)
    before=LW.loop_snapshot(t["minds"][ITEM_A]["offer"])
    @test LW.food_trade_plan!(t,ITEM_A,v,f.w.bodies[ITEM_A],nothing,0)===nothing
    @test LW.loop_snapshot(t["minds"][ITEM_A]["offer"])==before
    @test t["minds"][ITEM_A]["need_skipped"]==1
    plans=Any[]
    hungry=LW.Body(10.,0.,20.,0.)
    v=deepcopy(v);v["own_stock"]=[0,0,1,0]
    for seed in 1:32
        p=LW.food_trade_plan!(LW.food_trade_state(seed),ITEM_A,v,hungry,nothing,0)
        p===nothing && continue
        push!(plans,p)
        @test p["want_count"]>p["give_count"] && p["trade_gain"]>LW.FOOD_TRADE_TOLERANCE
    end
    @test !isempty(plans)
end
