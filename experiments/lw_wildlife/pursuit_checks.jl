include("animals_only.jl")
@testset "observed flee pursuit child" begin
    s,ps=animal_trial_world();p=ps[1];b=p.visual.body;local_state=LocalHunt(1)
    b.x=-40.;b.z=0.;b.state=P.CHASE;p.mode=:hunt
    pursuit=PredatorPursuit(1);physical=PredatorPhysiology(p)
    o=(id=1,x=-32.,z=0.,distance=8.)
    @test pursuit_radial(pursuit,b,o,10)===nothing
    pursuit.observed[1]=(x=-32.6,z=0.,tick=9)
    @test pursuit_radial(pursuit,b,o,10)≈.6
    # Deterministic preference for feasible pursuit, not a random test outcome.
    pursuit.loop.probabilistic=false
    # Selection logging must support both modes.
    physical.body=LW.Body(10.,0.,100.,0.)
    filtered,handled=configured_pursuit_observe!(pursuit,local_state,trial_proxy(s,p),[o],10;physiology=physical)
    @test handled && pursuit.active!==nothing && local_state.movement_speed==PREDATOR_PURSUIT.speed
    @test p.mode==:hunt && b.attacks==0
    configured_pursuit_close!(pursuit,30,"forecast_due";distance=8.)
    @test pursuit.loop.H>0 && pursuit.active===nothing
    @test last(pursuit.records).residual≈4.5
    @test local_state.loop.H==0
    old=physical.body;configured_pursuit_exert!(physical,1.)
    @test physical.body.reserve==old.reserve && physical.body.burst<old.burst && physical.body.strain>old.strain
    # Exhausted body admits only abandoning, but the parent hunt survives.
    physical.body=LW.Body(0.,0.,100.,0.);pursuit.observed[1]=(x=-32.6,z=0.,tick=39)
    filtered,handled=configured_pursuit_observe!(pursuit,local_state,trial_proxy(s,p),[o],40;physiology=physical)
    @test handled && haskey(pursuit.released,1) && b.target==0 && p.mode==:hunt
    # A newly observed stop clears the provisional release.
    configured_pursuit_observe!(pursuit,local_state,trial_proxy(s,p),[o],41;physiology=physical)
    @test !haskey(pursuit.released,1)
    io=IOBuffer();serialize(io,pursuit);seekstart(io);restored=deserialize(io)
    @test pursuit_report(restored)==pursuit_report(pursuit)
end
