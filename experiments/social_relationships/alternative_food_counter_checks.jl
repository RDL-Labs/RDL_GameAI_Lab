# Explicit fixtures exercise capabilities; they are not ordinary-world stock grants.
include("../portable_items/checks.jl")
@testset "private stock alternative is published only by a chosen counteroffer" begin
    f=item_fixture(objects=Any[],food_counts=[[0,0,0,0,0,0,5,0],[0,0,20,0,0,0,0,0],zeros(Int,8)],scene=(configured_negotiation=true,))
    for a in LW.IDS;f.w.positions[a]=(0.,0.);end
    first=item_act(f,ITEM_A,"item_offer",0;target=ITEM_B,give_food=[0,0,0,0,0,0,1,0],want_food=[1,0,0,0,0,0,0,0])
    @test first["status"]=="offered"
    before=deepcopy(f.foods.personal)
    peer_view=item_view(f,ITEM_A;now=1)
    @test LW.observed_food_count(peer_view,ITEM_B,3)===nothing
    m=LW.D();LW.food_remember_taste!(m,3,2,-1.,0);LW.food_remember_taste!(m,7,2,3.,0)
    state=LW.incidental_item_state(ITEM_B,1)
    plan=LW.item_social_plan!(state,item_view(f,ITEM_B;now=1),f.w.bodies[ITEM_B],nothing,f.foods.personal[ITEM_B],1;map=m)
    @test plan["action"]=="item_counter"
    @test plan["give_food"][1]==0 && 1<=plan["give_food"][3]<=4
    @test plan["want_food"][7]==1
    @test f.foods.personal==before
    if plan["action"]=="item_counter"
        published=item_act(f,ITEM_B,"item_counter",2;target=ITEM_A,offer_id=first["offer_id"],give_food=plan["give_food"],want_food=plan["want_food"])
        @test published["status"]=="offered"
        heard=item_view(f,ITEM_A;now=3)
        @test LW.observed_food_count(heard,ITEM_B,3)==plan["give_food"][3]
        @test LW.observed_food_count(heard,ITEM_B,3)!=20
        @test f.foods.personal==before
        recipient_map=LW.D()
        LW.food_remember_taste!(recipient_map,3,2,3.,0)
        LW.food_remember_taste!(recipient_map,7,2,-1.,0)
        recipient_plan=nothing
        for seed in 1:32
            trial=LW.item_social_plan!(LW.incidental_item_state(ITEM_A,seed),heard,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],3;map=recipient_map)
            if trial["action"]=="item_accept";recipient_plan=trial;break;end
        end
        @test recipient_plan!==nothing
        receipt=item_act(f,ITEM_A,"item_accept",4;offer_id=published["offer_id"])
        @test receipt["status"]=="exchanged"
        @test f.foods.personal[ITEM_A][3]==plan["give_food"][3]
        @test f.foods.personal[ITEM_B][7]==1
        @test item_checks(f)===nothing
        @test LW.observed_food_count(item_view(f,ITEM_A;now=5),ITEM_B,3)===nothing
    end
end
