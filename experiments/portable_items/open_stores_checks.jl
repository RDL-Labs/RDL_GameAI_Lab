# Explicit warehouse observations; no forced consent or private utility access.
include("checks.jl")
open_item_view(f,a;now=0)=LW.item_visible(f.s,f.w,ITEM_HOME,a,0.,now;open_stores=true,foods=f.foods)

@testset "open warehouses expose detached camp observations" begin
    f=barter_fixture();t=LW.food_trade_state(1)
    v=LW.food_exchange_view(t["world"],f.foods,f.w,ITEM_HOME,ITEM_A,0;open_stores=true)
    @test v["observed_food_stocks"][ITEM_B]==[0,0,3,0]
    v["observed_food_stocks"][ITEM_B][3]=999
    @test f.foods.personal[ITEM_B][3]==3
    @test !haskey(LW.food_exchange_view(t["world"],f.foods,f.w,ITEM_HOME,ITEM_A,0),"observed_food_stocks")
    iv=open_item_view(f,ITEM_A)
    @test any(r->r["ref"]==2 && r["holder"]==ITEM_B,iv["visible"])
    @test all(r->!haskey(r,"kind") && !haskey(r,"mass"),iv["visible"])
    @test iv["observed_food_stocks"][ITEM_B]==[0,0,3,0]
    iv["observed_food_stocks"][ITEM_B][3]=999
    @test f.foods.personal[ITEM_B][3]==3
    f.w.positions[ITEM_B]=(100.,100.) # the absent owner's store remains at camp
    @test any(r->r["ref"]==2,open_item_view(f,ITEM_A)["visible"])
    @test !(ITEM_B in open_item_view(f,ITEM_A)["trade_partners"])
    f.w.positions[ITEM_A]=(100.,100.)
    @test isempty(open_item_view(f,ITEM_A)["observed_food_stocks"])
    @test all(r->r["ref"]!=2,open_item_view(f,ITEM_A)["visible"])
    @test isempty(LW.food_exchange_view(t["world"],f.foods,f.w,ITEM_HOME,ITEM_A,0;open_stores=true)["observed_food_stocks"])
end

@testset "food requests use observed kinds and quantities" begin
    f=item_fixture(food_counts=[[0,0,3,0],[2,0,0,0],[0,0,0,0]])
    f.w.positions[ITEM_C]=(100.,100.)
    offers=0
    for seed in 1:32
        t=LW.food_trade_state(seed)
        views=LW.food_trade_views!(t,f.foods,f.w,ITEM_HOME,0;open_stores=true)
        p=LW.food_trade_plan!(t,ITEM_A,views[ITEM_A],f.w.bodies[ITEM_A],nothing,0;require_need=false)
        p===nothing && continue
        offers+=1
        @test p["target"]==ITEM_B && p["want_kind"]==1 && p["want_count"]<=2
    end
    @test offers>0
    # Observations are snapshots: current world edits cannot silently alter them.
    t=LW.food_trade_state(1)
    v=LW.food_exchange_view(t["world"],f.foods,f.w,ITEM_HOME,ITEM_A,0;open_stores=true)
    f.foods.personal[ITEM_B][1]=0
    @test v["observed_food_stocks"][ITEM_B][1]==2
    fresh=LW.food_exchange_view(t["world"],f.foods,f.w,ITEM_HOME,ITEM_A,0;open_stores=true)
    @test LW.food_trade_plan!(t,ITEM_A,fresh,f.w.bodies[ITEM_A],nothing,0;require_need=false)===nothing
end

@testset "mixed requests and refinements stay within observed food" begin
    f=item_fixture(objects=[placed_item(1,1;owner=ITEM_A,location="held")],
        food_counts=[[0,0,0,0],[2,0,0,0],[0,0,0,0]])
    f.w.positions[ITEM_C]=(100.,100.)
    offers=0
    for seed in 1:32
        state=LW.incidental_item_state(ITEM_A,seed)
        p=LW.item_social_plan!(state,open_item_view(f,ITEM_A),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],0)
        p===nothing && continue
        offers+=1
        @test p["target"]==ITEM_B && 0<p["want_food"][1]<=2 && all(iszero,p["want_food"][2:4])
    end
    @test offers>0
    # Counterproposals must obey the same observation, even if the other actor
    # has unseen meat in the authoritative state.
    f.foods.personal[ITEM_B][2]=10
    for seed in 1:32
        state=LW.incidental_item_state(ITEM_A,seed)
        v=open_item_view(f,ITEM_A);v["observed_food_stocks"][ITEM_B]=[2,0,0,0]
        v["incoming"]=Any[Dict("proposer"=>ITEM_B,"id"=>"fixture","round"=>0,
            "want_items"=>[1],"give_items"=>Int[],"want_food"=>zeros(Int,4),"give_food"=>zeros(Int,4))]
        p=LW.item_social_plan!(state,v,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],0)
        @test p!==nothing && p["action"] in ("item_counter","item_decline")
        p["action"]=="item_counter" && @test all(p["want_food"].<=[2,0,0,0])
    end
end
