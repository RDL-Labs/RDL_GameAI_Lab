include("checks.jl")

@testset "consensual requests and gifts" begin
    f=barter_fixture()
    offer=item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,want_items=[1])
    @test offer["status"]=="offered"
    @test f.s["items"][1]["owner"]==ITEM_A
    accepted=item_act(f,ITEM_A,"item_accept",1;offer_id=offer["offer_id"])
    @test accepted["status"]=="exchanged"
    @test f.s["items"][1]["owner"]==ITEM_B
    gift=item_act(f,ITEM_B,"item_offer",2;target=ITEM_A,give_items=[1])
    @test f.s["items"][1]["owner"]==ITEM_B
    item_act(f,ITEM_A,"item_decline",3;offer_id=gift["offer_id"])
    @test f.s["items"][1]["owner"]==ITEM_B
    @test item_checks(f)===nothing
end

@testset "observable interest shared by acquisition and exchange" begin
    s=LW.incidental_item_state(ITEM_A,9)
    f=item_fixture(objects=[placed_item(1,1;owner=ITEM_B,location="held"),
        placed_item(2,2;owner=ITEM_A,location="held"),placed_item(3,1;owner=ITEM_C,location="stored")])
    v=item_view(f,ITEM_A)
    @test any(x->x["ref"]==1 && x["holder"]==ITEM_B,v["visible"])
    @test all(x->x["ref"]!=3,v["visible"])
    @test all(x->!haskey(x,"kind") && !haskey(x,"mass"),v["visible"])
    values=LW.item_subjective_values(s,v)
    @test values[1]>values[2]
    dark=deepcopy(v)
    for row in dark["visible"];row["light_source"]=0.;end
    @test LW.item_subjective_values(s,dark)[1]<values[1]
    @test LW.incidental_item_interest(Dict("light_source"=>.02))≈.25
    # Hidden ownership and kind changes never enter valuation through this view.
    f.s["items"][3]["kind"]=65535
    @test LW.item_subjective_values(s,v)==values
    @test LW.item_social_gain(v["own"],[1,0,0,0],values,[1.,1.,1.,1.],Int[],[999],zeros(Int,4),zeros(Int,4))===nothing
end

@testset "autonomous visible possession negotiation and asynchronous credit" begin
    f=item_fixture(objects=[placed_item(1,1;owner=ITEM_B,location="held"),
        placed_item(2,2;owner=ITEM_A,location="held")])
    states=Dict(a=>LW.incidental_item_state(a,33) for a in (ITEM_A,ITEM_B))
    relations=Dict(a=>LW.social_relations_state(a;relational=true) for a in keys(states))
    pending_checked=false
    for t in 0:511
        now=t*1_000_000;LW.item_expire!(f.s,now)
        views=Dict(a=>item_view(f,a;now) for a in (ITEM_A,ITEM_B))
        for a in (ITEM_A,ITEM_B)
            LW.item_social_observe!(states[a],views[a];relation=relations[a])
            p=LW.item_social_plan!(states[a],views[a],f.w.bodies[a],nothing,f.foods.personal[a],now;relation=relations[a])
            p===nothing && continue
            result=item_act(f,a,p["action"],now;item_id=get(p,"item_id",0),target=get(p,"target",nothing),
                offer_id=get(p,"offer_id",nothing),give_items=get(p,"give_items",Int[]),want_items=get(p,"want_items",Int[]),
                give_food=get(p,"give_food",zeros(Int,4)),want_food=get(p,"want_food",zeros(Int,4)))
            LW.item_social_executed!(states[a],p,result;relation=relations[a])
            recorded=deepcopy(LW.item_social_snapshot(states[a]["social"]))
            @test !LW.item_social_executed!(states[a],p,result;relation=relations[a])
            @test LW.item_social_snapshot(states[a]["social"])==recorded
            if result["status"]=="offered"
                @test states[a]["social"]["offer"].trial!==nothing
                pending_checked=true
            end
        end
    end
    @test pending_checked
    @test f.s["counts"]["offered"]>0
    @test f.s["counts"]["exchanged"]>0
    @test f.s["counts"]["declined"]>0
    @test any(!isempty(s["social"]["records"]) for s in values(states))
    @test sum(r["mb"]["events"] for r in values(relations))>0
    @test all(length(s["social"]["offer"].methods)<=129 for s in values(states))
    @test item_checks(f)===nothing
    for s in values(states),r in s["social"]["records"]
        r["status"]!="exchanged" && @test r["actual"]==0
    end
end
