using Test
include("../../integrations/lightweight_julia/native.jl")
@testset "house attention boundary" begin
    h=(x=3.,z=0.,radius=.6)
    rows=[D("ref"=>string(i-1),"cost"=>1.,"clear"=>true) for i in eachindex(ANGLES)]
    s=configured_house_state()
    @test configured_house_plan!(s,h,(0.,0.),0.,0,100_000_000,rows)===nothing
    @test configured_house_plan!(s,h,(0.,0.),0.,0,100_000_000,rows;eligible=true,blocked=true)===nothing
    p=configured_house_plan!(s,h,(0.,0.),0.,0,100_000_000,rows;eligible=true)
    @test p["action"]=="walk"
    @test s["mode"]=="travelling"
    @test configured_house_plan!(s,h,(3.,0.),0.,1_000_000,100_000_000,rows)["action"]=="rest"
    @test s["entries"]==1
    @test !configured_house_wake!(s,2_000_000,100_000_000,.01;inside=true)
    @test configured_house_wake!(s,3_000_000,100_000_000,.2;inside=true)
    @test s["wakeups"]["body"]==1
    for reason in (:notice,:busy,:danger)
        s["mode"]="idle";s["day"]=0
        @test configured_house_wake!(s,4_000_000,100_000_000,0.;inside=true,NamedTuple{(reason,)}((true,))...)
        @test s["mode"]=="active"
    end
    s["mode"]="idle"
    @test !configured_house_wake!(s,5_000_000,100_000_000,.4;inside=true,sleeping=true)
    @test configured_house_wake!(s,6_000_000,100_000_000,.8;inside=true,sleeping=true)
    @test configured_house_wake!(s,100_000_000,100_000_000,0.;inside=true)
    @test !configured_house_wake!(s,101_000_000,100_000_000,0.;inside=true)
    @test configured_house_obligation(D("pending"=>1),nothing,nothing,nothing,"a",0)
    @test !configured_house_obligation(D("pending"=>nothing),nothing,nothing,nothing,"a",0)
end

@testset "return then sleep in own house" begin
    scene=merge(native_scene(9),(personal_house_idle=true,initial_inventory=[0,0,0],reserve=[100,100,100],
        positions=[[0.,4.],[0.,4.],[0.,4.]],food=Any[],obstacles=Any[],low_obstacles=Any[]))
    clock=merge(native_clock(),(day_us=80_000_000,phase_boundaries_us=[0,0,0,80_000_000],quiet_night_us=0,sleep_rest_us=10_000_000))
    r=lw_day(scene,clock;days=1)
    @test all(r["final_agents"][a]["personal_house"].inside for a in IDS)
    @test all(r["final_agents"][a]["sleep"]["sleep"]["external_gate"]["blocked_ticks"]>0 for a in IDS)
    @test any(e->get(e,"method",nothing)=="personal_house_return",r["events"])
    @test all(r["final_agents"][a]["body"]!=r["day_starts"][1][a]["body"] for a in IDS)
    daytime=merge(clock,(phase_boundaries_us=[0,0,80_000_000,80_000_000],quiet_night_us=80_000_000))
    awake=lw_day(scene,daytime;days=1)
    @test all(awake["daily"][1]["physical"][a]["house_attention"]["idle_ticks"]>0 for a in IDS)
    @test all(awake["daily"][1]["physical"][a]["house_attention"]["sleep_ticks"]==0 for a in IDS)
    mktempdir() do checkpoints
        lw_day(scene,daytime;days=1,checkpoint_dir=checkpoints)
        resumed=lw_day(scene,daytime;days=2,resume_from=joinpath(checkpoints,"day-001.jls"))
        full=lw_day(scene,daytime;days=2)
        @test resumed["counts"]==full["counts"]
        @test resumed["daily"]==full["daily"]
    end
end
