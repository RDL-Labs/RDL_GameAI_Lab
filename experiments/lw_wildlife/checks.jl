using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
const G=LW.LWGrazing
const H=G.H
const input=JSON3.read(read(joinpath(@__DIR__,"../rock_gate/channel_trial_spec.json"),String))
function scene(;count=3,seed=20261028)
    merge((;pairs(input.scene)...),(wildlife=(enabled=true,count=count,seed=seed),))
end
function isolated()
    s=G.build(scene(count=1),input.clock)
    empty!(s.world.obstacles)
    s.animals.x[1]=-10.;s.animals.z[1]=6.;s.animals.heading[1]=0.;s.gaze[1]=0.
    s.animals.current_cell[1]=H.cell(s.world,-10.,6.)
    s.world.traits.density.=0. # isolate vision from cover without changing food
    s
end
@testset "LW grazing geometry and private seed" begin
    @test G.build(input.scene,input.clock)===nothing
    s=G.build(scene(count=30),input.clock);other=G.build(scene(count=30),input.clock)
    @test s.initial_positions==other.initial_positions
    @test s.initial_positions!=G.build(scene(count=30,seed=20261029),input.clock).initial_positions
    @test length(unique(s.initial_positions))==30
    originals=vcat(collect(input.scene.obstacles),collect(input.scene.low_obstacles))
    @test [(o.x,o.z,o.radius) for o in s.world.obstacles]==[(o.x,o.z,o.radius) for o in originals if get(o,:solid,true)]
    @test all(p->H.clear(s.world,p,p),s.initial_positions)
    @test s.world.traits!==nothing && length(unique(s.world.traits.patch))<length(s.world.grass)
    @test_throws ErrorException G.build(merge(scene(),(world_history=(wildlife=nothing,),)),input.clock)
end
@testset "observed humans, alert, flight and release" begin
    s=isolated();human=[(-5.,6.),(100.,100.),(200.,200.)]
    G.prepare!(s,human,0)
    @test s.overrides[1]==H.ALERT
    G.advance!(s,0)
    @test (s.animals.x[1],s.animals.z[1])==(-10.,6.)
    @test s.alert_entries[1]==1
    human[1]=(-7.5,6.)
    G.prepare!(s,human,1)
    @test s.overrides[1]==H.FLEE
    G.advance!(s,1)
    @test s.animals.x[1]<-10.
    @test s.flee_entries[1]==1
    remembered=s.seen_position[1]
    human[1]=(100.,100.)
    G.prepare!(s,human,2)
    @test s.threats[1]==remembered
    @test s.overrides[1]==H.FLEE
    G.advance!(s,2)
    for t in 3:24;G.prepare!(s,human,t);G.advance!(s,t);end
    @test s.overrides[1]==0 && s.animals.state[1] in (H.GRAZE,H.REST,H.SEARCH,H.SLEEP)
    @test s.human_seen==[2,0,0]
    @test_throws ErrorException G.advance!(s,25)
    @test_throws ErrorException G.prepare!(s,human,24)
end
@testset "occlusion, peripheral field and visible target selection" begin
    s=isolated();push!(s.world.obstacles,H.RDLMigrationProbe.Circle(-8.,6.,.5))
    G.prepare!(s,[(-6.,6.),(100.,100.),(200.,200.)],0)
    @test s.overrides[1]==0 && s.seen_ticks[1]==0
    # Hidden nearest human must not suppress a farther visible one.
    s=isolated();push!(s.world.obstacles,H.RDLMigrationProbe.Circle(-8.,6.,.5))
    G.prepare!(s,[(-7.,6.),(-10.,10.),(200.,200.)],0)
    @test s.seen_actor[1]==2 && s.overrides[1]==H.ALERT
    s=isolated();s.animals.heading[1]=-(pi/6)*sin(1.) # cancel this tick's scan, gaze remains zero
    G.prepare!(s,[(-14.,6.),(100.,100.),(200.,200.)],0)
    @test s.seen_ticks[1]==0 # rear blind area
    s=isolated();s.world.traits.density.=1.;s.world.traits.height.=1.
    p=(-5.,6.);s.previous_humans[1]=p
    G.prepare!(s,[p,(100.,100.),(200.,200.)],0)
    @test s.seen_ticks[1]==0 # stationary human behind dense vegetation
    s=isolated();s.world.traits.density.=1.;s.world.traits.height.=1.
    s.previous_humans[1]=(-4.,6.)
    G.prepare!(s,[p,(100.,100.),(200.,200.)],0)
    @test s.seen_ticks[1]==1 # motion extends detection range
end
@testset "resource accounting, sleep and serialized continuation" begin
    s=G.build(scene(),input.clock);humans=[(100.,100.),(101.,100.),(102.,100.)]
    s.animals.sleepy[1]=1.1
    for t in 0:599;G.prepare!(s,humans,t);G.advance!(s,t);end
    @test s.animals.counts[1,H.SLEEP]>0
    report=G.snapshot(s)
    @test report.grass_eaten>0 && report.grass_grown>0
    @test report.grass_initial+report.grass_grown≈report.grass_eaten+report.grass_remaining
    io=IOBuffer();serialize(io,s);seekstart(io);resumed=deserialize(io)
    for t in 600:1199
        for state in (s,resumed);G.prepare!(state,humans,t);G.advance!(state,t);end
    end
    @test G.snapshot(s)==G.snapshot(resumed)
    @test :wildlife in LW.LW_CHECKPOINT_FIELDS
    @test report.alive==3
end

# Small real LW day boundaries verify the capture/restore macro, not just the module.
@testset "LW daily checkpoint includes grazing world" begin
    cfg=merge((;pairs(input.config)...),(days=2,))
    # Full day/clock calibration is retained. First-day observation keeps this cheap.
    sc=scene(count=3)
    fixture=(scene=sc,clock=input.clock,config=cfg)
    mktempdir() do dir
        continuous,_=LW.run_integrated(fixture;checkpoint_dir=dir)
        resumed,_=LW.run_integrated(fixture;resume_from=joinpath(dir,"day-001.jls"))
        @test continuous["wildlife"]==resumed["wildlife"]
        @test continuous["daily"]==resumed["daily"]
        @test continuous["counts"]==resumed["counts"]
        @test continuous["mb_map"]==resumed["mb_map"]
    end
end
