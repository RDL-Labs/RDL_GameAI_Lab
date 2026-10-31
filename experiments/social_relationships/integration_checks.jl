# Actual LW ticks: sensing, ordinary candidate competition, typed transfer,
# owner-local forecasts and Sleep consolidation must be wired together.
using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
const IA="npc_a";const IB="npc_b";const IC="npc_c"

function integration_clock(seconds;orientation=0,exploration=seconds,night=seconds)
    merge(LW.native_clock(),(day_us=seconds*1_000_000,
        phase_boundaries_us=[orientation,exploration,night,seconds].*1_000_000,
        quiet_night_us=night*1_000_000))
end
function integration_scene(;distance=.75,relationships=true)
    merge(LW.native_scene(19),(name="social-integration-controlled",positions=[[0.,0.],[0.,distance],[100.,100.]],
        home=[0.,0.],food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
        initial_inventory=[0,3,0],initial_inventory_kinds=[Int[],[4,4,4],Int[]],
        reserve=[30.,90.,100.],typed_food=true,food_exchange=true,social_relationships=relationships))
end
integration_run(scene,clock;seed=3,days=1,kwargs...)=LW.lw_day(scene,clock;days,basic_loop=true,
    food_body=true,social_response=true,choice_seed=seed,kwargs...)

@testset "LW social aid transfer and owner MB are connected" begin
    r=integration_run(integration_scene(),integration_clock(60;orientation=60))
    aid=r["final_agents"][IA]["aid"];rel=r["social_relationships"][IA]
    @test r["ended_us"]==60_000_000
    @test get(r["counts"][IA],"request",0)>0
    @test get(r["counts"][IB],"give",0)>0
    @test r["initial_food"]==r["ground"]+r["consumed"]+sum(a["inventory"]+a["personal_stock"] for a in values(r["final_agents"]))
    @test aid["rule"]=="owner-food-forecast-v1" && aid["resolved"]>1 && (aid["pending"]===nothing || aid["pending"]["deadline_us"]>=r["ended_us"])
    given=filter(x->x["outcome"]=="given",aid["records"])
    @test !isempty(given) && all(x->x["received_kind"]==4,given)
    @test all(x->x["actual"]==x["forecast"]["values"][4] && x["evaluated"],given)
    @test any(x->x["outcome"]=="refuse" && 0<x["pressure"]<1,aid["records"])
    @test any(x->x["reward"]>0 && x["H_after"]<x["H_before"],given)
    @test rel["relational"] && rel["mb"]["events"]>0 && !isempty(rel["mb"]["pending"])
    @test any(x->!isempty(x["forecast"]["mb_ids"]),aid["records"])
    # Forecast retention changes the amount eaten in this fixed 60-second window.
    @test 1<=r["food_resources"]["consumed"][4]<=3
    @test r["final_agents"][IA]["social"]["model"]==LW.social_initial()["model"]
    @test r["food_exchange"]!==nothing
end

@testset "LW visible approach reaches contact through ordinary walking" begin
    # Social walking competes probabilistically; use a fixed small seed set
    # instead of requiring every social opportunity to win over exploration.
    runs=[integration_run(integration_scene(distance=1.5),integration_clock(45);seed) for seed in 0:7]
    approaches=[r["social_relationships"][IA]["approach"] for r in runs]
    @test sum(a["proposed"] for a in approaches)>0 && sum(a["selected"] for a in approaches)>0
    @test sum(a["contacts"] for a in approaches)>0
    @test any(any(x->startswith(something(x["method"],""),"social_approach:") && x["action"]=="walk" && x["status"]=="performed",r["events"]) for r in runs)
    @test all(r["final_agents"][IA]["distance"]>0 for r in runs)
    @test any(r["final_agents"][IA]["aid"]["resolved"]>0 for r in runs)
end

@testset "LW stocked actors do not initiate unnecessary trade" begin
    scene=merge(integration_scene(),(initial_inventory=[0,0,0],initial_inventory_kinds=[Int[],Int[],Int[]],
        reserve=[90.,90.,100.],initial_personal_stock=[40,40,0],
        initial_personal_food_counts=(npc_a=[40,0,0,0],npc_b=[0,40,0,0],npc_c=zeros(Int,4))))
    r=integration_run(scene,integration_clock(512;orientation=512))
    exchange=r["food_exchange"];closed=exchange["world"]["counts"]
    @test closed["exchanged"]==0 && closed["offered"]==0
    @test !any(x["action"]=="trade_accept" for x in r["events"])
    @test sum(a["personal_stock"] for a in values(r["final_agents"]))==80
    @test all(r["food_resources"]["consumed"].==0)
    trade_events=vcat([exchange["learning"][a][role]["events"] for a in LW.IDS for role in ("offer","response")]...)
    @test isempty(trade_events)
    @test !any(n["channel"] in ("trade_offer","trade_response") for a in LW.IDS for n in values(r["social_relationships"][a]["mb"]["pending"]))
end

@testset "LW aid remains active after bounded legacy record storage fills" begin
    # Raw food remains useful predicted material but cannot be eaten away from
    # home. This maintains hunger and contact without a forced request action.
    scene=merge(integration_scene(),(home=[50.,50.],initial_inventory=[0,300,0],
        initial_inventory_kinds=[Int[],fill(3,300),Int[]]))
    r=integration_run(scene,integration_clock(1200;orientation=1200))
    a=r["final_agents"][IA];aid=a["aid"];social=a["social"]
    @test aid["resolved"]>192
    @test length(social["records"])<=128 && social["records_pruned"]>0
    @test aid["resolved"]==length(social["records"])+social["records_pruned"]
    @test maximum(e["us"] for e in aid["records"])>600_000_000
    @test sum(sum(values(counts)) for counts in values(aid["outcome_counts"]))==aid["resolved"]
end

@testset "LW Sleep adopts relation MBs and leaves the old model untouched" begin
    # Sleep still uses the production 2,880-second rest requirement. Keep that
    # duration and shorten only the waking schedule; no test-only Sleep trigger.
    r=integration_run(integration_scene(),integration_clock(3000;orientation=60,exploration=60,night=120))
    for a in LW.IDS
        mb=r["social_relationships"][a]["mb"]
        @test r["final_agents"][a]["sleep"]["sleep"]["cycle"]["status"]=="completed"
        @test length(mb["reviews"])==1 && mb["last_review_day"]==0
        @test mb["frozen"]===nothing
        @test r["final_agents"][a]["social"]["model"]==LW.social_initial()["model"]
    end
    @test !isempty(r["social_relationships"][IA]["mb"]["nodes"])
    # Anticipatory requests can also make A a responder; both channels are valid.
    @test all(n["channel"] in ("aid_received","aid_given") for n in values(r["social_relationships"][IA]["mb"]["nodes"]))
    legacy=integration_run(integration_scene(relationships=false),integration_clock(3000;orientation=60,exploration=60,night=120))
    @test !haskey(legacy,"social_relationships")
    @test !isempty(legacy["final_agents"][IA]["social"]["model"])
    @test legacy["final_agents"][IA]["social"]["cycles"]==[0]
end

@testset "LW checkpoint resumes an open social forecast without duplicate learning" begin
    scene=integration_scene();clock=integration_clock(5;orientation=5)
    full=integration_run(scene,clock;days=2)
    mktempdir() do directory
        # The test owns this generated temporary subtree, including automatic cleanup.
        @assert startswith(abspath(directory),joinpath(abspath(tempdir()),""))
        first=integration_run(scene,clock;checkpoint_dir=directory,checkpoint_identity="social-integration")
        checkpoint=joinpath(directory,"day-001.jls")
        saved=deserialize(checkpoint)
        @test saved.state[:relations][IA]["aid"]["pending"]!==nothing
        resumed=integration_run(scene,clock;days=2,resume_from=checkpoint,checkpoint_identity="social-integration")
        @test resumed["final_agents"][IA]["aid"]["resolved"]>first["final_agents"][IA]["aid"]["resolved"]
        # Object key iteration order is not replay state. Compare the complete
        # JSON value tree, retaining exact numeric values and array order.
        expected=JSON3.read(JSON3.write(full),Dict{String,Any})
        actual=JSON3.read(JSON3.write(resumed),Dict{String,Any})
        matches=isequal(expected,actual)
        if !matches
            println("checkpoint differing top-level fields: ",
                [k for k in keys(expected) if !isequal(expected[k],actual[k])])
        end
        @test matches
    end
end
