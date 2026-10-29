# World capability checks. Operations are explicit test inputs, not NPC desires.
using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
if !isdefined(LW,:portable_items)
    Base.include(LW,normpath(joinpath(@__DIR__,"../../src/lw/world/portable_items.jl")))
end
const ITEM_A="npc_a";const ITEM_B="npc_b";const ITEM_C="npc_c"
const ITEM_HOME=(0.,0.)

function placed_item(id,kind;owner=nothing,location="ground",x=0.,z=.5,kwargs...)
    merge(Dict{String,Any}("id"=>id,"kind"=>kind,"owner"=>owner,
        "location"=>location,"x"=>x,"z"=>z),Dict(string(k)=>v for (k,v) in kwargs))
end
function item_fixture(;objects=[placed_item(1,1),placed_item(2,2;x=.4),placed_item(3,3;x=.8)],
        food_counts=[[2,0,0,0],[0,0,3,0],[0,0,0,0]],typed=true,
        input_key=:portable_items,scene=(;))
    w=LW.world(true)
    for a in LW.IDS
        w.inventory[a]=0;w.bodies[a]=LW.RDLBody.Body(10.,0.,90.,0.)
    end
    stores=Dict(a=>sum(food_counts[i]) for (i,a) in enumerate(LW.IDS))
    # Keep caller types intact: a JSON round-trip may normalize 1.0 to 1.
    spec=merge((typed_food=typed,
        initial_personal_food_counts=Dict(Symbol(a)=>food_counts[i] for (i,a) in enumerate(LW.IDS))),
        NamedTuple{(input_key,)}((objects,)),scene)
    foods=typed ? LW.food_resources(spec,w,Any[],Int[],0,stores) : nothing
    s=LW.portable_items(spec,w)
    (s=s,w=w,foods=foods,stores=stores)
end
function item_act(f,a,action,now;op="item-test:$now:$a",kwargs...)
    LW.item_execute!(f.s,f.foods,f.w,f.stores,ITEM_HOME,a,op,action,now;kwargs...)
end
function item_view(f,a;now=0,yaw=0.)
    LW.item_visible(f.s,f.w,ITEM_HOME,a,yaw,now)
end
function item_saved_copy(x)
    io=IOBuffer();serialize(io,x);seekstart(io);deserialize(io)
end
function item_checks(f)
    LW.item_audit!(f.s,f.w)
    f.foods!==nothing && LW.food_audit!(f.foods,f.w,Int[],0,f.stores)
    nothing
end
function barter_fixture(;typed=true)
    item_fixture(;typed,objects=[placed_item(1,1;owner=ITEM_A,location="held"),
        placed_item(2,2;owner=ITEM_B,location="stored"),
        placed_item(3,3;owner=ITEM_C,location="stored")])
end
offer_item(f;now=0,kwargs...)=item_act(f,ITEM_A,"item_offer",now;target=ITEM_B,
    give_items=[1],want_items=[2],kwargs...)

@testset "physical item actions require an able actor" begin
    for body in (LW.Body(0.,0.,0.,0.),LW.Body(0.,0.,90.,1.),LW.Body(10.,1.,90.,0.))
        f=item_fixture();f.w.bodies[ITEM_A]=body
        before=deepcopy(f.s["items"])
        result=item_act(f,ITEM_A,"item_pickup",0;item_id=1)
        @test result["status"]=="unavailable" && result["reason"]=="body_limited"
        @test f.s["items"]==before && item_checks(f)===nothing
        @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)==result
        @test f.s["counts"]["unavailable"]==1
    end
end

@testset "portable item identity and strict input contracts" begin
    w=LW.world(true)
    @test LW.portable_items((;),w)===nothing
    f=item_fixture()
    @test item_checks(f)===nothing
    @test Set(keys(f.s["items"]))==Set([1,2,3])
    @test LW.item_snapshot(f.s)["initial_counts"]==[1,1,1]
    @test LW.item_snapshot(f.s)["remaining_counts"]==[1,1,1]
    for invalid in (true,1.0,"1",0,-1)
        @test_throws Exception item_fixture(objects=[placed_item(invalid,1)])
    end
    for invalid in (true,1.0,"1",0,65536,-1)
        @test_throws Exception item_fixture(objects=[placed_item(1,invalid)])
    end
    @test_throws Exception item_fixture(objects=[placed_item(1,1),placed_item(1,2)])
    @test_throws Exception item_fixture(objects=[placed_item(1,1;owner="stranger",location="held")])
    @test_throws Exception item_fixture(objects=[placed_item(1,1;location="held")])
    @test_throws Exception item_fixture(objects=[placed_item(1,1;location="missing")])
    for invalid in (NaN,Inf,-Inf)
        @test_throws Exception item_fixture(objects=[placed_item(1,1;x=invalid)])
    end
    @test_throws Exception item_fixture(objects=[placed_item(1,1;size=-1.)])
    @test_throws Exception item_fixture(objects=[placed_item(1,1;light_source=-1.)])
    @test_throws Exception item_fixture(objects=[placed_item(i,1) for i in 1:257])
end

@testset "pickup, personal storage and gift preserve identity and food" begin
    f=item_fixture();food_before=LW.food_snapshot(f.foods);body_before=deepcopy(f.w.bodies)
    first=item_act(f,ITEM_A,"item_pickup",0;item_id=1)
    @test first["status"]=="picked_up"
    @test f.s["items"][1]["owner"]==ITEM_A
    @test length(LW.item_inventory(f.s,ITEM_A)["held"])==1
    @test item_act(f,ITEM_B,"item_pickup",0;item_id=1)["status"]=="unavailable"
    @test item_act(f,ITEM_B,"item_give",1;item_id=1,target=ITEM_C)["status"]=="unavailable"
    @test item_act(f,ITEM_A,"item_store",2;item_id=1)["status"]=="stored"
    @test isempty(LW.item_inventory(f.s,ITEM_A)["held"])
    @test length(LW.item_inventory(f.s,ITEM_A)["stored"])==1
    @test item_act(f,ITEM_B,"item_retrieve",3;item_id=1)["status"]=="unavailable"
    @test item_act(f,ITEM_A,"item_give",4;item_id=1,target=ITEM_B)["status"]=="unavailable"
    @test item_act(f,ITEM_A,"item_retrieve",5;item_id=1)["status"]=="retrieved"
    @test item_act(f,ITEM_A,"item_give",6;item_id=1,target=ITEM_B)["status"]=="given"
    @test isempty(LW.item_inventory(f.s,ITEM_A)["held"])
    @test f.s["items"][1]["owner"]==ITEM_B
    @test item_act(f,ITEM_B,"item_drop",7;item_id=1)["status"]=="dropped"
    @test f.s["items"][1]["owner"]===nothing
    @test item_act(f,ITEM_C,"item_pickup",8;item_id=1)["status"]=="picked_up"
    @test f.s["items"][1]["owner"]==ITEM_C
    @test LW.food_snapshot(f.foods)==food_before && f.w.bodies==body_before
    @test all(==(0),values(f.w.inventory)) && item_checks(f)===nothing
    @test f.s["items"][1]["history_count"]>=6
    @test Set(keys(f.s["items"]))==Set([1,2,3])
end

@testset "world reach, contact and obstruction constrain operations" begin
    f=item_fixture(objects=[placed_item(1,1;z=2.)])
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)["status"]=="unavailable"
    f=item_fixture(objects=[placed_item(1,1;z=1.)])
    push!(f.w.obstacles,LW.RDLMigrationProbe.Circle(0.,.5,.2))
    @test isempty(item_view(f,ITEM_A)["visible"])
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)["status"]=="unavailable"
    empty!(f.w.obstacles)
    @test item_act(f,ITEM_A,"item_pickup",1;item_id=1)["status"]=="picked_up"
    f.w.positions[ITEM_B]=(5.,0.)
    @test item_act(f,ITEM_A,"item_give",2;item_id=1,target=ITEM_B)["status"]=="unavailable"
    f.w.positions[ITEM_B]=(.4,0.);f.w.hearing[ITEM_B]=false
    @test item_act(f,ITEM_A,"item_give",3;item_id=1,target=ITEM_B)["status"]=="unavailable"
    f.w.hearing[ITEM_B]=true;f.w.positions[ITEM_A]=(10.,0.)
    @test item_act(f,ITEM_A,"item_store",4;item_id=1)["status"]=="unavailable"
    @test f.s["items"][1]["owner"]==ITEM_A && item_checks(f)===nothing
end

@testset "actor views hide private storage and do not alias world state" begin
    f=barter_fixture();v=item_view(f,ITEM_A)
    @test !any(x->x["ref"] in (2,3),v["visible"])
    @test isempty(v["own"]["stored"]) && length(v["own"]["held"])==1
    hidden=item_saved_copy(f);hidden.s["items"][2]["color"]="secret-blue"
    hidden.foods.personal[ITEM_B][3]+=1;hidden.foods.initial[3]+=1;hidden.stores[ITEM_B]+=1
    @test item_view(hidden,ITEM_A)==v && item_checks(hidden)===nothing
    own=LW.item_inventory(f.s,ITEM_A);own["held"][1]["color"]="forged"
    @test LW.item_inventory(f.s,ITEM_A)["held"][1]["color"]!="forged"
    snap=LW.item_snapshot(f.s);snap["items"][1]["color"]="forged"
    @test f.s["items"][1]["color"]!="forged"
    offered=offer_item(f);id=offered["offer_id"]
    recipient=item_view(f,ITEM_B);recipient["incoming"][1]["give_items"][1]=999
    @test f.s["offers"][id]["give_items"]==[1]
    @test isempty(item_view(f,ITEM_C)["incoming"])
    item_act(f,ITEM_B,"item_accept",1;offer_id=id)
    notice=item_view(f,ITEM_A;now=1)["notices"]
    @test !isempty(notice)
    empty!(notice)
    @test !isempty(item_view(f,ITEM_A;now=1)["notices"])
end

@testset "barter moves both sides atomically without requiring food" begin
    f=barter_fixture(typed=false);before=LW.item_snapshot(f.s)
    id=offer_item(f)["offer_id"]
    @test f.s["items"][1]["owner"]==ITEM_A && f.s["items"][2]["owner"]==ITEM_B
    @test item_act(f,ITEM_C,"item_accept",1;offer_id=id)["status"]=="unavailable"
    @test haskey(f.s["offers"],id)
    receipt=item_act(f,ITEM_B,"item_accept",2;offer_id=id)
    @test receipt["status"]=="exchanged" && isempty(f.s["offers"])
    @test f.s["items"][1]["owner"]==ITEM_B && f.s["items"][2]["owner"]==ITEM_A
    @test f.s["items"][3]["owner"]==ITEM_C
    @test LW.item_snapshot(f.s)["remaining_counts"]==before["remaining_counts"]
    @test item_checks(f)===nothing
    f=barter_fixture();id=offer_item(f)["offer_id"]
    item_act(f,ITEM_A,"item_give",1;item_id=1,target=ITEM_C)
    before=LW.item_snapshot(f.s)["items"];stock=LW.food_snapshot(f.foods)
    @test item_act(f,ITEM_B,"item_accept",2;offer_id=id)["status"]=="unavailable"
    @test LW.item_snapshot(f.s)["items"]==before && LW.food_snapshot(f.foods)==stock
    @test item_checks(f)===nothing
end

@testset "item-food barter preserves typed food and validates before mutation" begin
    f=barter_fixture();before=copy(f.foods.initial)
    offer=item_act(f,ITEM_A,"item_offer",0;target=ITEM_B,give_items=[1],want_food=[0,0,2,0])
    accepted=item_act(f,ITEM_B,"item_accept",1;offer_id=offer["offer_id"])
    @test accepted["status"]=="exchanged" && f.s["items"][1]["owner"]==ITEM_B
    @test f.foods.personal[ITEM_A]==[2,0,2,0] && f.foods.personal[ITEM_B]==[0,0,1,0]
    @test f.stores[ITEM_A]==4 && f.stores[ITEM_B]==1
    @test f.foods.initial==before && item_checks(f)===nothing
    f=barter_fixture()
    offer=item_act(f,ITEM_A,"item_offer",0;target=ITEM_B,give_items=[1],want_food=[0,0,4,0])
    @test offer["status"]=="offered" # The proposer does not know the other warehouse.
    items_before=LW.item_snapshot(f.s)["items"];food_before=LW.food_snapshot(f.foods)
    @test item_act(f,ITEM_B,"item_accept",1;offer_id=offer["offer_id"])["status"]=="unavailable"
    @test LW.item_snapshot(f.s)["items"]==items_before && LW.food_snapshot(f.foods)==food_before
    @test item_checks(f)===nothing
    f=barter_fixture()
    offer=item_act(f,ITEM_A,"item_offer",0;target=ITEM_B,give_food=[1,0,0,0],want_items=[2])
    @test item_act(f,ITEM_B,"item_accept",1;offer_id=offer["offer_id"])["status"]=="exchanged"
    @test f.s["items"][2]["owner"]==ITEM_A && f.foods.personal[ITEM_B]==[1,0,3,0]
    @test item_checks(f)===nothing
end

@testset "receipts, denial, expiry and malformed commands cannot duplicate assets" begin
    f=item_fixture();receipt=item_act(f,ITEM_A,"item_pickup",0;item_id=1)
    snapshot=LW.item_snapshot(f.s)
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)==receipt
    @test LW.item_snapshot(f.s)==snapshot
    receipt["status"]="forged"
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)["status"]=="picked_up"
    @test_throws Exception item_act(f,ITEM_A,"item_pickup",0;item_id=2)
    @test_throws Exception item_act(f,ITEM_A,"item_pickup",0;op="another",item_id=1)
    for invalid in (true,1.,"1",-1,0)
        @test_throws Exception item_act(f,ITEM_A,"item_pickup",1;item_id=invalid)
    end
    item_act(f,ITEM_A,"item_drop",2;item_id=1)
    @test_throws Exception item_act(f,ITEM_A,"item_pickup",1;item_id=1)
    @test item_checks(f)===nothing
    for terms in ((give_items=[1,1],want_items=[2]),(give_items=[1],want_items=[1]),
            (give_items=[true],want_items=[2]),(give_items=[1.],want_items=[2]),
            (give_items=[1],want_food=[0,0,-1,0]),(give_items=[1],want_food=[0,0,5,0]),
            (give_items=[1],want_food=[0.,0.,1.,0.]),(give_items=[1],want_food=[false,false,true,false]),
            (give_items=[1],want_food=[0,0,1]),(give_items=[1],),
            (give_food=[1,0,0,0],want_food=[0,0,1,0]))
        bad=barter_fixture();before=LW.item_snapshot(bad.s)
        @test_throws Exception item_act(bad,ITEM_A,"item_offer",0;target=ITEM_B,terms...)
        @test LW.item_snapshot(bad.s)==before && item_checks(bad)===nothing
    end
    f=barter_fixture();id=offer_item(f)["offer_id"]
    before=LW.item_snapshot(f.s)["items"]
    @test item_act(f,ITEM_B,"item_decline",1;offer_id=id)["status"]=="declined"
    @test LW.item_snapshot(f.s)["items"]==before && isempty(f.s["offers"])
    f=barter_fixture();id=offer_item(f)["offer_id"]
    expires=f.s["offers"][id]["expires_us"]
    LW.item_expire!(f.s,expires)
    @test isempty(f.s["offers"]) && f.s["counts"]["expired"]==1
    @test item_act(f,ITEM_B,"item_accept",expires;offer_id=id)["status"]=="unavailable"
    @test f.s["items"][1]["owner"]==ITEM_A && item_checks(f)===nothing
end

@testset "moving light and bounded provenance survive serialization" begin
    f=item_fixture(objects=[placed_item(1,1;light_source=.1),placed_item(2,2)])
    light=only(LW.item_light_objects(f.s,f.w))
    @test light.x==0. && light.z==.5 && light.light_source==.1
    item_act(f,ITEM_A,"item_pickup",0;item_id=1)
    f.w.positions[ITEM_A]=(4.,5.)
    light=only(LW.item_light_objects(f.s,f.w))
    @test light.x==4. && light.z==5.
    f.w.positions[ITEM_A]=(0.,0.)
    item_act(f,ITEM_A,"item_store",1;item_id=1)
    @test isempty(LW.item_light_objects(f.s,f.w))
    for t in 2:101
        item_act(f,ITEM_A,iseven(t) ? "item_retrieve" : "item_store",t;item_id=1)
    end
    @test length(f.s["items"][1]["history"])<=32 && f.s["items"][1]["history_count"]>=102
    @test length(f.s["records"])<=128
    for notices in values(f.s["notices"]);@test length(notices)<=32;end
    restored=item_saved_copy(f)
    @test LW.item_snapshot(restored.s)==LW.item_snapshot(f.s) && item_checks(restored)===nothing
    @test item_act(restored,ITEM_A,"item_retrieve",102;item_id=1)==item_act(f,ITEM_A,"item_retrieve",102;item_id=1)
    @test LW.item_snapshot(restored.s)==LW.item_snapshot(f.s)
    f=barter_fixture();id=offer_item(f)["offer_id"];restored=item_saved_copy(f)
    @test item_act(f,ITEM_B,"item_accept",1;offer_id=id)==item_act(restored,ITEM_B,"item_accept",1;offer_id=id)
    @test LW.item_snapshot(f.s)==LW.item_snapshot(restored.s)
    @test LW.food_snapshot(f.foods)==LW.food_snapshot(restored.foods) && item_checks(restored)===nothing
end

@testset "loose objects accept generic kinds and registry defaults" begin
    objects=[placed_item(1,4),placed_item(2,99),placed_item(3,65535),placed_item(4,99)]
    old=item_fixture(;objects)
    f=item_fixture(;objects,input_key=:loose_items)
    @test LW.item_snapshot(f.s)==LW.item_snapshot(old.s)
    @test_throws Exception item_fixture(scene=(loose_items=Any[],))
    snap=LW.item_snapshot(f.s)
    @test snap["kind_ids"]==[1,2,3,4,99,65535]
    @test snap["initial_counts"]==[0,0,0,1,2,1]
    @test snap["remaining_counts"]==snap["initial_counts"]
    unknown=only(filter(x->x["id"]==2,snap["items"]))
    @test unknown["label"]=="item_99" && unknown["color"]=="neutral"
    @test unknown["size"]==.1 && unknown["mass"]==.1 && unknown["light_source"]==0.
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=2)["status"]=="picked_up"
    @test item_act(f,ITEM_A,"item_give",1;item_id=2,target=ITEM_B)["status"]=="given"
    @test f.s["items"][2]["kind"]==99 && f.s["items"][2]["owner"]==ITEM_B
    @test LW.item_snapshot(f.s)["remaining_counts"]==snap["initial_counts"] && item_checks(f)===nothing

    registry=[Dict("id"=>99,"label"=>"quartz","color"=>"white","size"=>.3,
        "mass"=>.7,"light_source"=>.04),Dict("id"=>1,"mass"=>.8)]
    f=item_fixture(objects=[placed_item(1,99),placed_item(2,99;color="red",mass=.2),placed_item(3,1)],
        input_key=:loose_items,scene=(item_kinds=registry,))
    snap=LW.item_snapshot(f.s)
    @test snap["kind_ids"]==[1,2,3,99] && snap["initial_counts"]==[1,0,0,2]
    @test snap["items"][1]["label"]=="quartz" && snap["items"][1]["mass"]==.7
    @test snap["items"][1]["color"]=="white" && snap["items"][1]["size"]==.3
    @test snap["items"][2]["color"]=="red" && snap["items"][2]["mass"]==.2
    @test snap["items"][2]["size"]==.3 && snap["items"][2]["light_source"]==.04
    @test snap["items"][3]["mass"]==.8 && snap["items"][3]["label"]=="glowing_stone"
    for invalid in (0.,-1.,NaN,Inf,true,"1")
        @test_throws Exception item_fixture(objects=[placed_item(1,99;mass=invalid)])
        @test_throws Exception item_fixture(objects=[placed_item(1,99;size=invalid)])
    end
    @test_throws Exception item_fixture(scene=(item_kinds=[Dict("id"=>99),Dict("id"=>99)],))
    @test_throws Exception item_fixture(scene=(item_kinds=[Dict("id"=>true)],))
    @test_throws Exception item_fixture(scene=(item_carry_limits=(mass=-1.,size=1.),))
    @test_throws Exception item_fixture(scene=(item_carry_limits=(mass=5.,size=Inf),))
end

@testset "mass is owner information and public views expose only appearance" begin
    objects=[placed_item(1,99;mass=1.2),placed_item(2,100;owner=ITEM_B,location="held",mass=.3)]
    f=item_fixture(;objects,input_key=:loose_items)
    view=item_view(f,ITEM_A)
    @test length(view["visible"])==2
    @test all(row->!haskey(row,"mass") && !haskey(row,"kind"),view["visible"])
    hidden=item_saved_copy(f);hidden.s["items"][2]["mass"]=4.
    @test item_view(hidden,ITEM_A)==view && item_checks(hidden)===nothing
    @test view["own_load"]["mass"]==0. && view["own_load"]["count"]==0
    @test view["carry_capacity"]["mass"]==5. && view["carry_capacity"]["size"]==1.
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)["status"]=="picked_up"
    view=item_view(f,ITEM_A)
    @test only(view["own"]["held"])["mass"]==1.2
    @test view["own_load"]["mass"]==1.2 && view["own_load"]["count"]==1
    view["own"]["held"][1]["mass"]=999.;view["carry_capacity"]["mass"]=999.
    @test only(LW.item_inventory(f.s,ITEM_A)["held"])["mass"]==1.2
    @test item_view(f,ITEM_A)["carry_capacity"]["mass"]==5.
end

@testset "size, mass, accumulated load and injury limit carrying" begin
    for attrs in ((size=1.01,mass=.1),(size=.1,mass=5.01))
        f=item_fixture(objects=[placed_item(1,99;attrs...)],input_key=:loose_items)
        before=LW.item_snapshot(f.s)["items"]
        result=item_act(f,ITEM_A,"item_pickup",0;item_id=1)
        @test result["status"]=="unavailable" && result["reason"]=="carry_capacity"
        @test LW.item_snapshot(f.s)["items"]==before && item_checks(f)===nothing
    end
    f=item_fixture(objects=[placed_item(1,99;mass=1.,size=.25),placed_item(2,99;mass=.01,size=.26)],
        scene=(item_carry_limits=(mass=1.,size=.25),))
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)["status"]=="picked_up"
    @test item_act(f,ITEM_A,"item_store",1;item_id=1)["status"]=="stored"
    @test item_act(f,ITEM_A,"item_pickup",2;item_id=2)["status"]=="unavailable"

    f=item_fixture(objects=[placed_item(1,99;mass=4.),placed_item(2,100;mass=2.)])
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)["status"]=="picked_up"
    @test item_act(f,ITEM_A,"item_pickup",1;item_id=2)["reason"]=="carry_capacity"
    @test item_view(f,ITEM_A;now=1)["own_load"]["mass"]==4.
    @test item_act(f,ITEM_A,"item_store",2;item_id=1)["status"]=="stored"
    @test item_view(f,ITEM_A;now=2)["own_load"]["mass"]==0.
    @test item_act(f,ITEM_A,"item_pickup",3;item_id=2)["status"]=="picked_up"
    before=LW.item_snapshot(f.s)["items"]
    @test item_act(f,ITEM_A,"item_retrieve",4;item_id=1)["reason"]=="carry_capacity"
    @test LW.item_snapshot(f.s)["items"]==before
    @test item_act(f,ITEM_A,"item_drop",5;item_id=2)["status"]=="dropped"
    @test item_act(f,ITEM_A,"item_retrieve",6;item_id=1)["status"]=="retrieved"
    @test item_checks(f)===nothing

    f=item_fixture(objects=[placed_item(i,99;size=.6,mass=.1) for i in 1:3])
    for i in 1:3
        @test item_act(f,ITEM_A,"item_pickup",i;item_id=i)["status"]=="picked_up"
    end
    load=item_view(f,ITEM_A;now=3)["own_load"]
    @test load["size"]==.6 && load["mass"]≈.3 && load["count"]==3
    f=item_fixture(objects=[placed_item(1,99;mass=3.),placed_item(2,100;mass=1.)])
    f.w.bodies[ITEM_A]=LW.Body(10.,0.,90.,.5)
    @test item_view(f,ITEM_A)["carry_capacity"]["mass"]==2.5
    @test item_act(f,ITEM_A,"item_pickup",0;item_id=1)["reason"]=="carry_capacity"
    @test item_act(f,ITEM_A,"item_pickup",1;item_id=2)["status"]=="picked_up"
    f.w.bodies[ITEM_A]=LW.Body(10.,0.,90.,.9)
    @test item_act(f,ITEM_A,"item_drop",2;item_id=2)["status"]=="dropped"
    @test item_checks(f)===nothing # Existing overload must not prevent unloading.
end

@testset "gifts and barter validate final capacity without partial transfers" begin
    f=item_fixture(objects=[placed_item(1,99;owner=ITEM_A,location="held",mass=3.),
        placed_item(2,100;owner=ITEM_B,location="held",mass=3.)])
    before=LW.item_snapshot(f.s)["items"]
    result=item_act(f,ITEM_A,"item_give",0;item_id=1,target=ITEM_B)
    @test result["status"]=="unavailable" && result["reason"]=="carry_capacity"
    @test LW.item_snapshot(f.s)["items"]==before
    @test item_act(f,ITEM_B,"item_store",1;item_id=2)["status"]=="stored"
    f.w.bodies[ITEM_B]=LW.Body(10.,0.,90.,.5)
    @test item_act(f,ITEM_A,"item_give",2;item_id=1,target=ITEM_B)["reason"]=="carry_capacity"
    f.w.bodies[ITEM_B]=LW.Body(10.,0.,90.,0.)
    @test item_act(f,ITEM_A,"item_give",3;item_id=1,target=ITEM_B)["status"]=="given"
    @test item_checks(f)===nothing

    # Both are already full: the swap fits only after deducting what each gives.
    f=item_fixture(objects=[placed_item(1,99;owner=ITEM_A,location="held",mass=5.),
        placed_item(2,100;owner=ITEM_B,location="held",mass=5.)])
    id=offer_item(f;give_food=[1,0,0,0],want_food=[0,0,1,0])["offer_id"]
    @test item_act(f,ITEM_B,"item_accept",1;offer_id=id)["status"]=="exchanged"
    @test f.s["items"][1]["owner"]==ITEM_B && f.s["items"][2]["owner"]==ITEM_A
    @test item_view(f,ITEM_A;now=1)["own_load"]["mass"]==5.
    @test item_view(f,ITEM_B;now=1)["own_load"]["mass"]==5.
    @test f.foods.personal[ITEM_A]==[1,0,1,0] && f.foods.personal[ITEM_B]==[1,0,2,0]
    @test item_checks(f)===nothing

    for overloaded in (ITEM_A,ITEM_B)
        # Only one side would exceed capacity; neither food nor objects may move.
        amass,bmass=overloaded==ITEM_A ? (1.,4.) : (4.,1.)
        f=item_fixture(objects=[placed_item(1,99;owner=ITEM_A,location="held",mass=amass),
            placed_item(2,100;owner=ITEM_B,location="held",mass=bmass),
            placed_item(3,101;owner=overloaded,location="held",mass=4.)])
        id=offer_item(f;give_food=[1,0,0,0],want_food=[0,0,1,0])["offer_id"]
        before=LW.item_snapshot(f.s)["items"];food_before=LW.food_snapshot(f.foods);stores_before=copy(f.stores)
        result=item_act(f,ITEM_B,"item_accept",1;offer_id=id)
        @test result["status"]=="unavailable" && result["reason"]=="carry_capacity"
        @test LW.item_snapshot(f.s)["items"]==before && LW.food_snapshot(f.foods)==food_before
        @test f.stores==stores_before && item_checks(f)===nothing
    end
    # Exchanging private stored objects never charges a recipient's held load.
    f=item_fixture(objects=[placed_item(1,99;owner=ITEM_A,location="held",mass=5.),
        placed_item(2,100;owner=ITEM_B,location="stored",mass=50.,size=2.)])
    id=offer_item(f)["offer_id"]
    @test item_act(f,ITEM_B,"item_accept",1;offer_id=id)["status"]=="exchanged"
    @test f.s["items"][2]["owner"]==ITEM_A && f.s["items"][2]["location"]==LW.ITEM_STORED
    @test item_act(f,ITEM_A,"item_retrieve",2;item_id=2)["reason"]=="carry_capacity"
    @test item_checks(f)===nothing
end

@testset "generic kinds, limits and pending barter survive serialization" begin
    f=item_fixture(input_key=:loose_items,
        scene=(item_kinds=[Dict("id"=>99,"label"=>"quartz","mass"=>.7)],
            item_carry_limits=(mass=2.,size=.5)),
        objects=[placed_item(1,99;owner=ITEM_A,location="held"),
            placed_item(2,65535;owner=ITEM_B,location="held",mass=.8)])
    id=offer_item(f)["offer_id"];restored=item_saved_copy(f)
    @test LW.item_snapshot(f.s)==LW.item_snapshot(restored.s)
    @test item_view(f,ITEM_A)==item_view(restored,ITEM_A)
    @test item_act(f,ITEM_B,"item_accept",1;offer_id=id)==item_act(restored,ITEM_B,"item_accept",1;offer_id=id)
    @test LW.item_snapshot(f.s)==LW.item_snapshot(restored.s)
    @test LW.food_snapshot(f.foods)==LW.food_snapshot(restored.foods)
    @test LW.item_snapshot(restored.s)["kind_ids"]==[1,2,3,99,65535]
    @test LW.item_snapshot(restored.s)["initial_counts"]==[0,0,0,1,1] && item_checks(restored)===nothing
end
