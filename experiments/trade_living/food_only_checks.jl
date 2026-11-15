include("../portable_items/checks.jl")
@testset "food-only exchange uses ordinary consent and accounting" begin
    f=item_fixture(objects=Any[],food_counts=[[20,0,0,0],[0,0,0,20],[0,0,0,0]],scene=(food_batch_expiry=true,))
    offer=item_act(f,ITEM_A,"item_offer",0;target=ITEM_B,give_food=[1,0,0,0],want_food=[0,0,0,1])
    @test offer["status"]=="offered"
    @test f.foods.personal[ITEM_A][1]==20 # proposal alone does not move food
    accepted=item_act(f,ITEM_B,"item_accept",1;offer_id=offer["offer_id"])
    @test accepted["status"]=="exchanged"
    @test f.foods.personal[ITEM_A][4]==1 && f.foods.personal[ITEM_B][1]==1
    @test item_act(f,ITEM_B,"item_accept",1;offer_id=offer["offer_id"])==accepted
    @test f.foods.personal[ITEM_A][4]==1
    @test item_checks(f)===nothing
    @test LW.food_age_audit!(f.foods)===nothing
    # Same actual world, autonomous proposal/response planner, no item possessions.
    states=Dict(a=>LW.incidental_item_state(a,33) for a in (ITEM_A,ITEM_B))
    before=f.s["counts"]["exchanged"]
    for t in 2:1024
        now=t*1_000_000;LW.item_expire!(f.s,now)
        for a in (ITEM_A,ITEM_B)
            view=item_view(f,a;now,open_stores=true)
            LW.item_social_observe!(states[a],view)
            plan=LW.item_social_plan!(states[a],view,f.w.bodies[a],nothing,f.foods.personal[a],now)
            plan===nothing && continue
            result=item_act(f,a,plan["action"],now;target=get(plan,"target",nothing),offer_id=get(plan,"offer_id",nothing),
                give_items=get(plan,"give_items",Int[]),want_items=get(plan,"want_items",Int[]),
                give_food=get(plan,"give_food",zeros(Int,8)),want_food=get(plan,"want_food",zeros(Int,8)))
            LW.item_social_executed!(states[a],plan,result)
        end
        f.s["counts"]["exchanged"]>before && break
    end
    @test sum(LW.item_social_state!(s)["decisions"] for s in values(states))>0
    @test f.s["counts"]["exchanged"]>before
    @test item_checks(f)===nothing
    @test LW.food_age_audit!(f.foods)===nothing
end
