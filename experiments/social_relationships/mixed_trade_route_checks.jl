using Test, Serialization
include("../../src/lw/LW.jl")

# Explicit world operations test the unified route, not an NPC desire script.
clock=merge(LW.native_clock(),(day_us=16_000_000,
    phase_boundaries_us=[0,0,16_000_000,16_000_000],quiet_night_us=16_000_000))
scene=merge(LW.native_scene(19),(positions=[[0.,0.],[.1,0.],[0.,.1]],home=[0.,0.],
    food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
    initial_inventory=[0,0,0],initial_inventory_kinds=[Int[],Int[],Int[]],
    reserve=[95.,95.,95.],typed_food=true,food_exchange=true,
    incidental_items=true,item_exchange=true,loose_items=Any[],open_stores=true,
    initial_personal_stock=[2,2,0],
    initial_personal_food_counts=(npc_a=[2,0,0,0],npc_b=[0,0,2,0],npc_c=zeros(Int,4))))

# Fail loudly if any normal-world path silently falls back to the old controller.
@eval LW food_trade_state(seed;relational=false)=error("legacy controller invoked")

@testset "mixed-only runtime and restart" begin
    mktempdir() do dir
        run(s=scene;kwargs...)=LW.lw_day(s,clock;days=2,basic_loop=true,
            landmark_routes=true,choice_seed=33,kwargs...)
        result=run(checkpoint_dir=dir)
        saved=deserialize(joinpath(dir,"day-001.jls"))
        @test saved.state[:trades]===nothing
        @test !haskey(result,"food_exchange")
        @test result["world_checkpoint"]["food_exchange"]===nothing
        @test all(!haskey(d,"food_exchange") for d in result["daily"])
        resumed=run(resume_from=joinpath(dir,"day-001.jls"))
        for key in ("portable_items","incidental_items","final_agents","daily")
            @test result[key]==resumed[key]
        end
        # The former switch no longer adds a second source of choices or RNG use.
        no_legacy_flag=run(merge(scene,(food_exchange=false,)))
        for key in ("portable_items","incidental_items","final_agents","daily")
            @test result[key]==no_legacy_flag[key]
        end
        @test_throws "food_exchange_requires_mixed_item_exchange" run(merge(scene,(item_exchange=false,)))
        # Even a custom experiment bypassing the source hash cannot revive old state.
        saved.state[:trades]=LW.D("world"=>LW.D())
        historical=joinpath(dir,"historical.jls")
        serialize(historical,saved)
        @test_throws "legacy_food_trade_checkpoint_requires_frozen_source" run(resume_from=historical)
    end
end

@testset "food-only bundle uses the mixed transaction world" begin
    w=LW.world(true)
    for a in LW.IDS;w.inventory[a]=0;end
    stores=Dict("npc_a"=>2,"npc_b"=>2,"npc_c"=>0)
    foods=LW.food_resources(scene,w,Any[],Int[],0,stores)
    items=LW.portable_items(scene,w)
    before=foods.personal["npc_a"]+foods.personal["npc_b"]
    offer=LW.item_execute!(items,foods,w,stores,(0.,0.),"npc_a","offer","item_offer",0;
        target="npc_b",give_food=[1,0,0,0],want_food=[0,0,1,0])
    @test offer["status"]=="offered"
    receipt=LW.item_execute!(items,foods,w,stores,(0.,0.),"npc_b","accept","item_accept",1;
        offer_id=offer["offer_id"])
    @test receipt["status"]=="exchanged"
    @test foods.personal["npc_a"][1:4]==[1,0,1,0]
    @test foods.personal["npc_b"][1:4]==[1,0,1,0]
    @test before==foods.personal["npc_a"]+foods.personal["npc_b"]
end
