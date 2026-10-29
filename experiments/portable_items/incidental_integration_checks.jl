# Short, explicit geometry fixture. The pickup choices themselves are autonomous.
using Test, JSON3
include("../../src/lw/LW.jl")
const INC_IDS=LW.IDS
const INC_CLOCK=merge(LW.native_clock(),(day_us=120_000_000,
    phase_boundaries_us=[1_000_000,120_000_000,120_000_000,120_000_000],quiet_night_us=120_000_000))
function incidental_scene(;enabled=true)
    positions=[[0.,0.],[8.,0.],[0.,8.]]
    # Keep actors in their local observation cell so each has repeated, optional
    # choices. B carries provisions and retains the ordinary return purpose.
    rocks=Any[(x=p[1]+.7sind(a),z=p[2]+.7cosd(a),radius=.22,height=2.,color="gray") for p in positions for a in 0:30:330]
    objects=Any[(id=3(i-1)+k,kind=k,x=p[1]+.05k,z=p[2]+.05) for (i,p) in enumerate(positions) for k in 1:3]
    merge(LW.native_scene(19),(name="incidental-pickup-integration",positions=positions,home=[0.,0.],
        food=Any[],obstacles=rocks,low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
        initial_inventory=[0,6,0],reserve=[95.,95.,95.],loose_items=objects,incidental_items=enabled))
end
incidental_run(scene;kwargs...)=LW.lw_day(scene,INC_CLOCK;basic_loop=true,landmark_routes=true,
    mb_simulation=true,mb_chunks=true,choice_seed=73,kwargs...)
@testset "optional pickups occur during food and return without parent success" begin
    r=incidental_run(incidental_scene())
    @test r["portable_items"]["counts"]["picked_up"]>0
    @test all(get(r["counts"][a],"item_pickup",0)>0 for a in INC_IDS)
    @test r["incidental_items"]["npc_b"]["succeeded"]>0
    @test any(x["family"]=="food" for a in INC_IDS for x in r["incidental_items"][a]["records"])
    @test any(x["family"]=="home" for x in r["incidental_items"]["npc_b"]["records"])
    @test r["final_agents"]["npc_b"]["return_purpose"]["active"]
    @test r["final_agents"]["npc_b"]["return_purpose"]["completed"]==0
    @test all(r["mb_map"][a]["parent_mb"]["successes"]==0 for a in INC_IDS)
    @test all(r["incidental_items"][a]["continued"]>0 for a in INC_IDS)
    @test all(r["incidental_items"][a]["failed"]==0 for a in INC_IDS)
    @test all(v["body"]["reserve"]>0 for v in values(r["final_agents"]))
    @test r["initial_food"]==6 && r["consumed"]==0 && r["final_agents"]["npc_b"]["inventory"]==6
    @test r["portable_items"]["remaining_counts"]==[3,3,3]
    @test all(get(r["counts"][a],"walk",0)+get(r["counts"][a],"scan",0)>0 for a in INC_IDS)
    @test all(r["incidental_items"][a]["selected"]==get(r["counts"][a],"item_pickup",0) for a in INC_IDS)
end
@testset "disabled mode and existing protected actions" begin
    r=incidental_run(incidental_scene(enabled=false))
    @test !haskey(r,"incidental_items")
    @test r["portable_items"]["counts"]["picked_up"]==0
    without_flag=(; (k=>v for (k,v) in pairs(incidental_scene(enabled=false)) if k!=:incidental_items)...)
    @test JSON3.read(JSON3.write(r))==JSON3.read(JSON3.write(incidental_run(without_flag)))
    # Initial camp observation remains an explicit protected experiment phase.
    q=incidental_run(incidental_scene();configured_observation_enabled=true)
    @test all(q["incidental_items"][a]["decisions"]==0 for a in INC_IDS)
    @test q["portable_items"]["counts"]["picked_up"]==0
    orientation=merge(INC_CLOCK,(phase_boundaries_us=fill(INC_CLOCK.day_us,4),))
    q=LW.lw_day(incidental_scene(),orientation;basic_loop=true,landmark_routes=true)
    @test all(q["incidental_items"][a]["decisions"]==0 for a in INC_IDS)
    deposit_scene=merge(incidental_scene(),(positions=[[0.,0.],[0.,0.],[0.,8.]],))
    q=incidental_run(deposit_scene)
    @test first(filter(e->e["actor"]=="npc_b",q["events"]))["action"]=="deposit"
    night=merge(INC_CLOCK,(phase_boundaries_us=[0,0,0,120_000_000],quiet_night_us=0))
    q=LW.lw_day(incidental_scene(),night;basic_loop=true,landmark_routes=true)
    @test all(q["incidental_items"][a]["decisions"]==0 for a in INC_IDS)
    @test q["portable_items"]["counts"]["picked_up"]==0
end
@testset "checkpoint preserves optional-choice RNG experience and parent state" begin
    scene=incidental_scene();identity="incidental-pickup-integration"
    mktempdir() do dir
        full=incidental_run(scene;days=2,checkpoint_dir=dir,checkpoint_identity=identity)
        resumed=incidental_run(scene;days=2,resume_from=joinpath(dir,"day-001.jls"),checkpoint_identity=identity)
        @test JSON3.read(JSON3.write(full))==JSON3.read(JSON3.write(resumed))
        @test full["incidental_items"]==full["daily"][end]["incidental_items"]
    end
end
