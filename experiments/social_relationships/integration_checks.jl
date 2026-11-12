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
function integration_scene(;distance=.75,relationships=true,donor_stock=3)
    merge(LW.native_scene(19),(name="social-integration-controlled",positions=[[0.,0.],[0.,distance],[100.,100.]],
        home=[0.,0.],food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
        initial_inventory=[0,donor_stock,0],initial_inventory_kinds=[Int[],fill(4,donor_stock),Int[]],
        reserve=[30.,90.,100.],typed_food=true,food_exchange=true,social_relationships=relationships))
end
integration_run(scene,clock;seed=3,days=1,kwargs...)=LW.lw_day(scene,clock;days,basic_loop=true,
    food_body=true,social_response=true,choice_seed=seed,kwargs...)

@testset "LW social aid transfer and owner MB are connected" begin
    # Usable donor surplus. A successful meal may remove the need for another
    # request; the 64 s cadence is an opportunity, not a compulsory request.
    r=integration_run(integration_scene(donor_stock=10),integration_clock(192;orientation=192))
    aid=r["final_agents"][IA]["aid"];rel=r["social_relationships"][IA]
    @test r["ended_us"]==192_000_000
    @test get(r["counts"][IA],"request",0)>0
    @test get(r["counts"][IB],"give",0)>0
    @test r["initial_food"]==r["ground"]+r["consumed"]+sum(a["inventory"]+a["personal_stock"] for a in values(r["final_agents"]))
    @test aid["rule"]=="owner-food-forecast-v1" && aid["resolved"]>=1 && (aid["pending"]===nothing || aid["pending"]["deadline_us"]>=r["ended_us"])
    given=filter(x->x["outcome"]=="given",aid["records"])
    @test !isempty(given) && all(x->x["received_kind"]==4,given)
    @test all(x->x["actual"]==x["forecast"]["values"][4] && x["evaluated"],given)
    @test all(x->x["evaluated"],aid["records"])
    # A first successful request starts at H=0: positive reward need not reduce H below zero.
    # Relief from positive H is checked separately in aid_forecast_checks.jl.
    @test any(x->x["reward"]>0 && x["H_after"]<=x["H_before"],given)
    @test rel["relational"] && rel["mb"]["events"]>0 && !isempty(rel["mb"]["pending"])
    # First contact has no earlier MB to cite. Experience is recorded in the
    # relationship pending list checked above; refusal/recall have unit coverage.
    @test isempty(first(aid["records"])["forecast"]["mb_ids"])
    # Forecast retention changes the amount eaten in this fixed 192-second window.
    @test 1<=r["food_resources"]["consumed"][4]<=10
    @test r["final_agents"][IA]["social"]["model"]==LW.social_initial()["model"]
    @test r["food_exchange"]!==nothing
end

@testset "LW visible approach reaches contact through ordinary walking" begin
    # Social walking competes probabilistically; use a fixed small seed set
    # instead of requiring every social opportunity to win over exploration.
    runs=[integration_run(integration_scene(distance=1.5,donor_stock=10),integration_clock(192);seed) for seed in 0:7]
    approaches=[r["social_relationships"][IA]["approach"] for r in runs]
    @test sum(a["proposed"] for a in approaches)>0 && sum(a["selected"] for a in approaches)>0
    @test sum(a["contacts"] for a in approaches)>0
    @test any(any(x->startswith(something(x["method"],""),"social_approach:") && x["action"]=="walk" && x["status"]=="performed",r["events"]) for r in runs)
    @test all(r["final_agents"][IA]["distance"]>0 for r in runs)
    @test any(r["final_agents"][IA]["aid"]["resolved"]>0 for r in runs)
end

@testset "LW stocked actors trade by compound value within the daily limit" begin
    scene=merge(integration_scene(),(initial_inventory=[0,0,0],initial_inventory_kinds=[Int[],Int[],Int[]],
        reserve=[90.,90.,100.],initial_personal_stock=[40,40,0],
        initial_personal_food_counts=(npc_a=[40,0,0,0],npc_b=[0,40,0,0],npc_c=zeros(Int,4))))
    r=integration_run(scene,integration_clock(512;orientation=512))
    exchange=r["food_exchange"];closed=exchange["world"]["counts"]
    @test closed["exchanged"]>0 && closed["offered"]>0
    @test any(x["action"]=="trade_accept" for x in r["events"])
    for actor in LW.IDS
        @test count(x->x["actor"]==actor && x["action"]=="trade_offer" && x["status"]=="offered",r["events"])<=1
    end
    @test sum(a["personal_stock"] for a in values(r["final_agents"]))==80
    @test all(r["food_resources"]["consumed"].==0)
    trade_events=vcat([exchange["learning"][a][role]["events"] for a in LW.IDS for role in ("offer","response")]...)
    @test !isempty(trade_events)
    @test all(e->e.evaluated && isfinite(e.actual),trade_events)
    # Pending MBs are waking experiences awaiting Sleep consolidation, not
    # unresolved exchange offers. Successful trades should create them.
    @test any(n["channel"] in ("trade_offer","trade_response") for a in LW.IDS for n in values(r["social_relationships"][a]["mb"]["pending"]))
end

@testset "observed aid receipts remain usable after legacy window fills" begin
    # Controlled message/receipt fixture, not 200 forced NPC requests in 1200 seconds.
    # Exercise the same ingest -> owner forecast -> bounded legacy window sequence as LW.
    social=LW.social_initial();aid=LW.social_aid_state(IA;seed=3)
    for i in 1:200
        now=(i-1)*64_000_000;id="aid-$i";op="request-$i"
        social["pending"]=LW.D("message_id"=>id,"operation_id"=>op,"target"=>IB,"deadline"=>now+5_000_000)
        LW.social_aid_begin!(aid,id,IB,now;probability=.5,values=[1.],expected_kind=1)
        outcome=isodd(i) ? "given" : "refuse"
        packet=LW.D("agent_id"=>IA,"capture_us"=>now+2_000_000,"observation_id"=>"obs-$i",
            "social"=>LW.D("messages"=>[LW.D("reply_to"=>id,"sender"=>IB,"kind"=>outcome,"food_kind"=>1,"time"=>(now+1_000_000)/1e6)]))
        social=LW.ingest(social,packet,LW.D(op=>LW.D("status"=>"expressed")))
        record=social["records"][id]
        LW.social_aid_finish!(aid,id,IB,record["outcome"],record["tick"];received_kind=get(record,"received_kind",nothing),source=record["source_observation_id"])
        LW.social_record_window!(social)
        @test social["pending"]===nothing && haskey(social["records"],id)
        @test aid["resolved"]==i && length(social["records"])<=128
    end
    @test length(social["records"])==128 && social["records_pruned"]==72
    @test aid["resolved"]==length(social["records"])+social["records_pruned"]==200
    @test sum(sum(values(counts)) for counts in values(aid["outcome_counts"]))==200
    @test last(aid["records"])["request_id"]=="aid-200"
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
    # Save immediately after the request, before the next-tick response. A five
    # second day already settles it and the current retry interval is 64 seconds.
    scene=integration_scene(donor_stock=10);clock=integration_clock(1;orientation=1)
    full=integration_run(scene,clock;days=3)
    mktempdir() do directory
        # The test owns this generated temporary subtree, including automatic cleanup.
        @assert startswith(abspath(directory),joinpath(abspath(tempdir()),""))
        first=integration_run(scene,clock;checkpoint_dir=directory,checkpoint_identity="social-integration")
        checkpoint=joinpath(directory,"day-001.jls")
        saved=deserialize(checkpoint)
        @test saved.state[:relations][IA]["aid"]["pending"]!==nothing
        resumed=integration_run(scene,clock;days=3,resume_from=checkpoint,checkpoint_identity="social-integration")
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
