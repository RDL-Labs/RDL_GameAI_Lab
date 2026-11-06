include("animals_only.jl")
function probability_fixture()
    s,ps=animal_trial_world();p=ps[1];b=p.visual.body
    empty!(s.world.obstacles);s.world.boundary_gradient=false
    b.x=-30.;b.z=6.;b.heading=0.;b.state=P.ATTACK;b.timer=3;b.target=1;b.attacks=1
    p.mode=:hunt;s.animals.x[1]=-29.;s.animals.z[1]=6.;s.animals.state[1]=H.GRAZE
    p.visual.previous_prey[1]=(-29.,6.)
    s,p,b
end
@testset "probabilistic capture world" begin
    chance=G.configured_capture_chance
    @test chance(.5,true,.5,0.,0.)>chance(2.,true,.5,0.,0.)
    @test chance(1.,false,.5,0.,0.)>chance(1.,true,.5,0.,0.)
    @test chance(1.,true,1.,0.,0.)>chance(1.,true,0.,0.,0.)
    @test chance(1.,true,.5,.5,0.)>chance(1.,true,.5,-.5,0.)
    @test chance(1.,true,.5,0.,0.)>chance(1.,true,.5,0.,1.)
    s,p,b=probability_fixture()
    @test G.configured_capture_path(s.world,(-30.,6.),(-29.,6.))
    @test !G.configured_capture_path(s.world,(-30.,6.),(-26.,6.))
    push!(s.world.obstacles,H.RDLMigrationProbe.Circle(-29.5,6.,.1))
    @test !G.configured_capture_path(s.world,(-30.,6.),(-29.,6.))
    # Blocked and out-of-range attacks cannot win, regardless of random draw.
    for blocked in (true,false)
        s,p,b=probability_fixture();b.timer=1
        if blocked
            push!(s.world.obstacles,H.RDLMigrationProbe.Circle(-29.5,6.,.1))
        else
            s.animals.x[1]=-20.
        end
        G.configured_probability_advance!(trial_proxy(s,p),0,0.)
        @test b.captures==0 && b.misses==1 && s.alive[1]
        @test last(p.visual.events).probability==0.
        @test b.state==P.CHASE && b.timer==0
    end
    s,p,b=probability_fixture()
    for t in 1:2
        G.configured_probability_advance!(trial_proxy(s,p),t,0.)
        @test isempty(p.visual.events) && b.misses==0 && b.captures==0
    end
    io=IOBuffer();serialize(io,(s,p));seekstart(io);copy_s,copy_p=deserialize(io)
    G.configured_probability_advance!(trial_proxy(s,p),3,0.)
    G.configured_probability_advance!(trial_proxy(copy_s,copy_p),3,0.)
    @test p.visual.events==copy_p.visual.events
    @test b.captures+b.misses==1 && length(p.visual.events)==1
    @test count(!,s.alive)==b.captures
end
@testset "subjective capture learning" begin
    s,p,b=probability_fixture();state=LocalHunt(1;probabilistic_capture=true)
    forecast=(x=-29.,z=6.,vx=0.,vz=0.)
    before=local_capture_estimate(state,(-30.,6.),forecast)
    candidate=LW.D("method"=>"attack","question"=>"capture","priority"=>1.,"target_id"=>1,
        "capture_context"=>before.key,"capture_expected"=>before.value)
    state.selected=LW.choose_method!(state.loop,[candidate],1)
    state.loop.H=3.;b.misses=1;b.state=P.CHASE
    configured_local_hunt_finish!(state,p)
    @test local_capture_estimate(state,(-30.,6.),forecast).value<before.value
    @test state.capture_experience[before.key]==(1,0) && state.loop.H==3.
    state.selected=LW.choose_method!(state.loop,[candidate],2);state.last_misses=b.misses
    b.captures=1
    configured_local_hunt_finish!(state,p)
    @test state.capture_experience[before.key]==(2,1)
    @test local_capture_estimate(state,(-30.,6.),forecast).value>(2*.6/3)
end
