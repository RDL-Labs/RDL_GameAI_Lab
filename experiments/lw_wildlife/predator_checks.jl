using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
const G=LW.LWGrazing;const H=G.H;const P=G.P
const predator_input=JSON3.read(read(joinpath(@__DIR__,"../rock_gate/channel_trial_spec.json"),String))
function predator_world(;enabled=true,reproduction=true)
    scene=merge((;pairs(predator_input.scene)...),(wildlife=(enabled=true,count=6,seed=42,
        reproduction=reproduction,initial_young_count=reproduction ? 3 : 0,
        initial_pregnancy_days=reproduction ? [26] : Int[],predator_count=enabled ? 1 : 0),))
    G.build(scene,predator_input.clock)
end
@testset "predator configuration and actual visible prey" begin
    s=predator_world();@test s.predator!==nothing
    @test predator_world(enabled=false).predator===nothing
    @test_throws ErrorException G.build(merge((;pairs(predator_input.scene)...),
        (wildlife=(enabled=true,predator_count=2),)),predator_input.clock)
    empty!(s.world.obstacles);s.world.traits.density.=0.
    p=s.predator.body;p.x=-10.;p.z=6.;p.heading=0.;s.predator.gaze=0.
    s.animals.x.=-20.;s.animals.z.=20.;s.animals.x[1]=-5.;s.animals.z[1]=6.
    G.configured_wildlife_predator_plan!(s,0)
    @test p.target==1 && p.state==P.CHASE
    seen=(p.seen_x,p.seen_z)
    push!(s.world.obstacles,H.RDLMigrationProbe.Circle(-8.,6.,.5))
    s.animals.x[1]=-4.
    G.configured_wildlife_predator_plan!(s,1)
    @test (p.seen_x,p.seen_z)==seen # Occlusion cannot update a hidden target.
end
@testset "capture is unique, counted and cancels pregnancy investment" begin
    s=predator_world();empty!(s.world.obstacles);s.world.traits.density.=0.
    victim=findfirst(>(0),s.life.due);p=s.predator.body
    s.animals.x.=-20.;s.animals.z.=20.
    s.animals.x[victim]=-9.5;s.animals.z[victim]=6.;s.animals.state[victim]=H.REST
    # Controlled world contact, not an autonomous pursuit fixture.
    for t in 0:100
        !s.alive[victim] && break
        p.x=-10.;p.z=6.;p.heading=0.;p.state=P.ATTACK;p.timer=1;p.attacks+=1
        G.configured_wildlife_predator_advance!(s,t)
    end
    @test !s.alive[victim] && p.captures==1
    @test s.life.due[victim]==0 && s.life.invested[victim]==0
    @test s.life.lost_pregnancies==1 && s.life.lost_investment>0
    @test p.state==P.REST
    G.configured_wildlife_predator_advance!(s,101)
    @test p.captures==1
    @test G.rabbit_reproduction_snapshot(s).balances.gestation.status=="ok"
end
@testset "same-world predation and serialized continuation" begin
    s=predator_world();humans=[(100.,100.) for _ in predator_input.scene.positions]
    # Controlled initial encounter; subsequent selection and contact remain autonomous.
    empty!(s.world.obstacles);s.world.traits.density.=0.
    s.predator.body.x=-10.;s.predator.body.z=6.;s.predator.body.heading=0.;s.predator.gaze=0.
    s.animals.x[1]=-8.;s.animals.z[1]=6.;s.animals.heading[1]=pi;s.gaze[1]=pi
    s.animals.current_cell[1]=H.cell(s.world,-8.,6.)
    for t in 0:599;G.prepare!(s,humans,t);G.advance!(s,t);end
    io=IOBuffer();serialize(io,s);seekstart(io);resumed=deserialize(io)
    for t in 600:1199, state in (s,resumed);G.prepare!(state,humans,t);G.advance!(state,t);end
    report=G.snapshot(s)
    @test report==G.snapshot(resumed)
    @test report.count==report.alive+report.starvation_deaths+report.predation_deaths
    @test report.predator.seen_by_rabbits>0
    @test report.predator.attacks>0
    @test all(x->x.status=="ok",values(report.balances))
    objects=LW.wildlife_motion_objects(s,collect(zip(s.animals.x,s.animals.z)))
    @test length(objects)==report.alive+1
    p=s.predator.body
    features=LW.wildlife_view((p.x-1.,p.z),0.,objects)
    @test any(x->x["appearance"]=="medium_furred_pointed_snout_body",features)
    @test all(x->!haskey(x,"danger"),features)
end
