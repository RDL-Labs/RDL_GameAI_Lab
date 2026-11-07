include("animals_only.jl")
@testset "direct water route is not prey rejection" begin
    s,ps=animal_trial_world();p=ps[1];b=p.visual.body;state=LocalHunt(1)
    river=12+5sin(-6/22+s.world.phase)
    b.x=river-4;b.z=0.;b.state=P.CHASE;b.target=1;b.expires=100
    b.seen_x=river+4;b.seen_z=0.;p.mode=:hunt
    obs=[(id=1,x=river+4,z=0.,distance=8.),(id=2,x=river-5,z=0.,distance=1.)]
    @test configured_predator_water_crossing(s.world,(b.x,b.z),(obs[1].x,0.))
    @test !configured_predator_water_crossing(s.world,(b.x,b.z),(obs[2].x,0.))
    original,H_before=state.loop.sequence,state.loop.H
    kept,changed=configured_predator_water_targets!(state,trial_proxy(s,p),obs,1)
    @test changed && only(kept).id==2
    @test b.target==0 && b.state==P.SEARCH && p.mode==:hunt
    @test state.loop.sequence==original && state.loop.H==H_before
    b.x=river+5
    kept,changed=configured_predator_water_targets!(state,trial_proxy(s,p),obs[1:1],2)
    @test !changed && only(kept).id==1 # same prey is available from this bank
    @test first(configured_predator_water_targets!(state,trial_proxy(s,p),obs,3;enabled=false))===obs
    b.x=river-4;b.target=1;b.state=P.CHASE;b.expires=100
    @test configured_local_hunt_plan!(state,trial_proxy(s,p),obs[1:1],4)
    @test b.target==0 && b.state==P.SEARCH && b.attacks==0
end
