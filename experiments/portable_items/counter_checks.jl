# Lower-level negotiation regression fixture: necessity is explicitly disabled here.
include("checks.jl")
@testset "counter replacement is atomic and requires new consent" begin
    f=barter_fixture()
    o=item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,want_items=[1])
    id=o["offer_id"];before=deepcopy(f.s["items"])
    bad=item_act(f,ITEM_C,"item_counter",1;target=ITEM_B,offer_id=id,want_items=[1])
    @test bad["status"]=="unavailable" && haskey(f.s["offers"],id)
    bad=item_act(f,ITEM_A,"item_counter",2;target=ITEM_B,offer_id=id,give_items=[2],want_items=[1])
    @test bad["status"]=="unavailable" && haskey(f.s["offers"],id)
    q=item_act(f,ITEM_A,"item_counter",3;target=ITEM_B,offer_id=id,give_items=[1],want_food=[0,0,1,0])
    @test q["status"]=="offered" && !haskey(f.s["offers"],id)
    @test f.s["items"]==before
    next=f.s["offers"][q["offer_id"]]
    @test next["counter_of"]==id && next["round"]==1
    @test next["expires_us"]==LW.ITEM_OFFER_TTL_US
    stale=item_act(f,ITEM_A,"item_accept",4;offer_id=id)
    @test stale["status"]=="unavailable"
    accepted=item_act(f,ITEM_B,"item_accept",5;offer_id=q["offer_id"])
    @test accepted["status"]=="exchanged"
    @test f.s["items"][1]["owner"]==ITEM_B
    @test f.foods.personal[ITEM_A][3]==1
    @test item_checks(f)===nothing
end
@testset "loss is never a random accept; counter terms are optional" begin
    f=item_fixture(objects=[placed_item(1,1;owner=ITEM_A,location="held"),
        placed_item(2,2;owner=ITEM_B,location="held")])
    o=item_act(f,ITEM_B,"item_offer",0;target=ITEM_A,want_items=[1])
    counters=0;declines=0
    for seed in 1:64
        s=LW.incidental_item_state(ITEM_A,seed)
        p=LW.item_social_plan!(s,item_view(f,ITEM_A;now=1),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;require_need=false)
        @test p!==nothing && p["action"] in ("item_counter","item_decline")
        if p["action"]=="item_counter"
            counters+=1
            @test p["subjective_gain"]>=-.01
            @test p["offer_id"]==o["offer_id"] && p["target"]==ITEM_B
            @test p["item_social_role"]=="response"
        else
            declines+=1
        end
    end
    @test counters>0 && declines>0
    @test f.s["items"][1]["owner"]==ITEM_A
    f.s["offers"][o["offer_id"]]["round"]=8
    s=LW.incidental_item_state(ITEM_A,1)
    p=LW.item_social_plan!(s,item_view(f,ITEM_A;now=1),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1;require_need=false)
    @test p["action"]=="item_decline"
end
