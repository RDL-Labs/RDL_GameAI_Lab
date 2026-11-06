include("animals_only.jl")
include("local_wait_checks.jl")
function repair_fixture()
    s,ps=animal_trial_world();p=ps[1];b=p.visual.body
    empty!(s.world.obstacles);s.world.boundary_gradient=false
    b.x=-30.;b.z=6.;b.heading=0.;b.state=P.ATTACK;b.timer=2;b.target=1;b.attacks=1
    p.mode=:hunt
    state=LocalHunt(1)
    state.selected=LW.choose_method!(state.loop,[LW.D("method"=>"attack","question"=>"capture","priority"=>1.,"target_id"=>1)],1)
    state.loop.H=3.;state.last_captures=b.captures;state.last_misses=b.misses
    s,p,b,state
end
@testset "route repair preserves hunt" begin
    s,p,b,state=repair_fixture()
    # A fleeing target cannot be caught in three forecast steps; next step is safe.
    state.memory[1]=(x=-33.7,z=6.,tick=0)
    observations=[(id=1,x=-34.,z=6.,distance=4.)]
    @test local_hunt_rollout(s.world,(b.x,b.z),(x=-34.,z=6.,vx=-.7,vz=0.))===nothing
    state.memory[1]=(x=-33.3,z=6.,tick=0)
    trial=state.loop.trial
    @test configured_local_hunt_plan!(state,trial_proxy(s,p),observations,1)
    @test b.state==P.ATTACK && b.timer==2 && b.target==1
    @test state.loop.trial===trial && state.loop.H==3.
    @test state.counts["uncertain_continuation"]==1
    s,p,b,state=repair_fixture()
    push!(s.world.obstacles,H.RDLMigrationProbe.Circle(-29.5,6.,.1))
    @test configured_local_hunt_plan!(state,trial_proxy(s,p),[(id=1,x=-27.,z=6.,distance=3.)],1)
    @test b.state==P.CHASE && b.timer==0 && b.target==1 && p.mode==:hunt
    @test b.misses==1 && state.loop.H==3.
    @test state.loop.methods["attack"].H>0
    @test state.selected["method"] in ("left","right","withdraw","wait")
    @test all(c.method!="attack" for c in last(state.records).candidates)
    # Physical failure clears old child exactly once, with target and parent retained.
    s,p,b,state=repair_fixture();b.misses+=1;P.recover!(b)
    configured_local_hunt_finish!(state,p)
    @test b.state==P.CHASE && b.timer==0 && b.target==1
    @test state.selected===nothing && state.loop.trial===nothing && state.loop.H==3.
    configured_local_hunt_finish!(state,p)
    @test state.counts["route_retry"]==1
    # No seen prey: last observed position remains a cue; no recovery pause.
    s,p,b,state=repair_fixture();b.expires=20;b.seen_x=-27.;b.seen_z=6.
    @test configured_local_hunt_plan!(state,trial_proxy(s,p),NamedTuple[],1)
    @test b.state==P.CHASE && b.target==1 && b.timer==0 && state.loop.H==3.
    # Parent plan identity, deadline and accumulated expenditure survive a local revision.
    s,p,b,state=repair_fixture();mind=PredatorMind(1)
    c=only(filter(c->c["action"]==:hunt,predator_candidates(mind,p,(actor=nothing,distance=Inf),nothing,1)))
    mind.selected=LW.choose_method!(mind.loop,[c],1)
    mind.trial=LW.action_trial(1,"hunt","acquired_food",c["forecast"])
    mind.start_spent=p.spent;parent_trial=mind.trial
    LW.action_trial_step!(parent_trial,100.,10.)
    configured_local_route_replan!(state,trial_proxy(s,p),100,"route_blocked")
    @test mind.trial===parent_trial && parent_trial["elapsed"]==100. && parent_trial["energy"]==10.
    @test parent_trial["forecast"]==c["forecast"] && mind.selected["action"]==:hunt
end
local_wait_checks()
