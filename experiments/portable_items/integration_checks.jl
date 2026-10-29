# Real LW ticks with an explicit operation fixture, not autonomous collection.
using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
const IA="npc_a";const IB="npc_b";const IC="npc_c"
cmd(a,t,action;kwargs...)=Dict{String,Any}("actor"=>a,"us"=>t*1_000_000,"action"=>action,
    (String(k)=>v for (k,v) in kwargs)...)
function item_scene(;actions=true)
    script=[cmd(IA,0,"item_pickup";item_id=1),cmd(IB,0,"item_pickup";item_id=2),cmd(IC,0,"item_pickup";item_id=3),
        cmd(IA,1,"item_store";item_id=1),cmd(IB,1,"item_store";item_id=2),cmd(IC,1,"item_store";item_id=3),
        cmd(IA,2,"item_retrieve";item_id=1),cmd(IA,3,"item_give";item_id=1,target=IB),cmd(IB,4,"item_store";item_id=1),
        cmd(IB,5,"item_offer";target=IA,give_items=[1],want_food=[1,0,0,0]),
        cmd(IA,6,"item_accept";offer_id="npc_b:5000000:op:5000000:npc_b"),
        cmd(IA,7,"item_retrieve";item_id=1),cmd(IA,8,"item_drop";item_id=1),
        cmd(IC,9,"item_offer";target=IB,give_items=[3],want_items=[2]),
        cmd(IB,10,"item_accept";offer_id="npc_c:9000000:op:9000000:npc_c"),
        cmd(IB,11,"item_pickup";item_id=1),
        cmd(IB,12,"item_offer";target=IC,give_items=[1],want_items=[2]),
        cmd(IC,13,"item_decline";offer_id="npc_b:12000000:op:12000000:npc_b"),cmd(IB,14,"item_store";item_id=1)]
    merge(LW.native_scene(19),(name="portable-items-operation-fixture",positions=[[0.,0.],[.5,0.],[-.5,0.]],
        home=[0.,0.],food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
        initial_inventory=[0,0,0],initial_inventory_kinds=[Int[],Int[],Int[]],reserve=[95.,95.,95.],
        typed_food=true,food_exchange=false,social_relationships=false,initial_personal_stock=[2,0,0],
        initial_personal_food_counts=(npc_a=[2,0,0,0],npc_b=zeros(Int,4),npc_c=zeros(Int,4)),
        portable_items=[(id=1,kind=1,x=0.,z=.3),(id=2,kind=2,x=.5,z=.3),(id=3,kind=3,x=-.5,z=.3)],
        configured_item_actions=actions ? script : Any[]))
end
const CLOCK=merge(LW.native_clock(),(day_us=10_000_000,phase_boundaries_us=fill(10_000_000,4),quiet_night_us=10_000_000))
item_run(s;kwargs...)=LW.lw_day(s,CLOCK;basic_loop=true,landmark_routes=true,kwargs...)

@testset "LW portable actions conserve items and food without inventing utility" begin
    r=item_run(item_scene();days=2)
    items=r["portable_items"];counts=items["counts"]
    @test counts["picked_up"]==4 && counts["stored"]==5 && counts["retrieved"]==2
    @test counts["given"]==1 && counts["dropped"]==1 && counts["offered"]==3
    @test counts["exchanged"]==2 && counts["declined"]==1 && counts["unavailable"]==0
    @test r["food_resources"]["personal"][IA]==[1,0,0,0]
    @test r["food_resources"]["personal"][IB]==[1,0,0,0]
    @test r["initial_food"]==2 && r["consumed"]==0
    @test sum(a["personal_stock"] for a in values(r["final_agents"]))==2
    @test all(a["inventory"]==0 for a in values(r["final_agents"]))
    @test length(items["items"])==3
    @test any(e["action"]=="item_give" && e["status"]=="item_given" for e in r["events"])
    @test !any(e["status"] in ("picked_up","recovered") for e in r["events"])
    @test all(l["H"]==0 && isempty(l["methods"]) for a in values(r["daily"][end]["physical"]) for l in values(a["loops"]))
    @test r["world_checkpoint"]["portable_items"]==items
    @test length(r["daily"])==2 && r["day_starts"][2]==r["daily"][1]["physical"]
    @test !isempty(r["daily"][1]["portable_items"]["active"])
end

@testset "placement alone does not force collection or trade" begin
    r=item_run(item_scene(actions=false))
    @test all(iszero,values(r["portable_items"]["counts"]))
    @test all(x["owner"]===nothing for x in r["portable_items"]["items"])
    hungry=merge(item_scene(actions=false),(reserve=[60.,95.,95.],
        configured_item_actions=[cmd(IA,0,"item_pickup";item_id=1)]))
    h=item_run(hungry)
    @test h["portable_items"]["counts"]["picked_up"]==0
    @test h["consumed"]>0 # existing food need precedes an operation fixture
    @test_throws ErrorException LW.configured_item_actions((configured_item_actions=[cmd(IA,0,"item_pickup";item_id=1)],),false)
    @test_throws ErrorException LW.configured_item_actions((configured_item_actions=[cmd(IA,0,"item_pickup";item_id=1),cmd(IA,0,"item_drop";item_id=1)],),true)
end

@testset "a data-only new kind uses the same LW pickup gift and barter" begin
    d=JSON3.read(JSON3.write(item_scene(actions=false)),Dict{String,Any})
    delete!(d,"portable_items")
    d["item_kinds"]=[Dict("id"=>4242,"label"=>"wood_fragment","color"=>"brown","size"=>.3,"mass"=>.25)]
    d["loose_items"]=[Dict("id"=>41,"kind"=>4242,"x"=>0.,"z"=>.3)]
    d["configured_item_actions"]=[cmd(IA,0,"item_pickup";item_id=41),cmd(IA,1,"item_give";item_id=41,target=IB),
        cmd(IB,2,"item_store";item_id=41),cmd(IB,3,"item_offer";target=IA,give_items=[41],want_food=[1,0,0,0]),
        cmd(IA,4,"item_accept";offer_id="npc_b:3000000:op:3000000:npc_b")]
    r=item_run(JSON3.read(JSON3.write(d)))
    item=only(r["portable_items"]["items"])
    @test item["kind"]==4242 && item["label"]=="wood_fragment" && item["owner"]==IA
    @test r["portable_items"]["counts"]["given"]==1 && r["portable_items"]["counts"]["exchanged"]==1
    @test r["food_resources"]["personal"][IA][1]==1 && r["food_resources"]["personal"][IB][1]==1
    @test sum(r["portable_items"]["remaining_counts"])==1 && 4242 in r["portable_items"]["kind_ids"]
end

@testset "day checkpoint resumes an accepted item offer exactly once" begin
    scene=item_scene();full=item_run(scene;days=2)
    mktempdir() do dir
        @assert startswith(abspath(dir),joinpath(abspath(tempdir()),""))
        first=item_run(scene;checkpoint_dir=dir,checkpoint_identity="portable-items-fixture")
        path=joinpath(dir,"day-001.jls");saved=deserialize(path)
        @test haskey(saved.state,:items) && length(saved.state[:items]["offers"])==1
        resumed=item_run(scene;days=2,resume_from=path,checkpoint_identity="portable-items-fixture")
        @test isequal(JSON3.read(JSON3.write(full),Dict{String,Any}),JSON3.read(JSON3.write(resumed),Dict{String,Any}))
        @test resumed["portable_items"]["counts"]["exchanged"]==first["portable_items"]["counts"]["exchanged"]+1
    end
    r=item_run(scene)
    @test_throws ErrorException item_run(merge(scene,(world_history=JSON3.read(JSON3.write(r["world_checkpoint"])),)))
end
