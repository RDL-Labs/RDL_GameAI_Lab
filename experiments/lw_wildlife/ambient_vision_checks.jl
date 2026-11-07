include("animals_only.jl")
@testset "shared ambient vision" begin
    v=LW.AmbientVision
    @test v.RULE==G.AmbientVision.RULE
    for species in (:human,:predator,:rabbit)
        @test v.range_factor(species,1.)==1.
        @test v.range_factor(species,0.)<v.range_factor(species,.5)<1
    end
    @test v.range_factor(:human,0.)<v.range_factor(:rabbit,0.)<v.range_factor(:predator,0.)
    @test v.illumination(11519)==1 && v.illumination(11520)==0
    @test v.illumination(17280)==1
    @test_throws ArgumentError v.range_factor(:human,-1.)
    obj=[(actor="",x=0.,z=4.,vx=.1,vz=0.)]
    @test LW.task_motion_notice((0.,0.),0.,obj;illumination=1.)!==nothing
    @test LW.task_motion_notice((0.,0.),0.,obj;illumination=0.)===nothing
    @test isempty(LW.wildlife_view((0.,0.),0.,obj;illumination=0.))
    objects=[(x=0.,z=20.,radius=2.,height=8.,color="red",light_source=1.)]
    @test !isempty(LW.landmark_fan(objects,(0.,0.),0.,"test";all_colors=true)["features"])
    dark=LW.landmark_fan(objects,(0.,0.),0.,"test";night=true,all_colors=true)
    @test isempty(dark["features"]) && !isempty(dark["lights"])
    @test isempty(LW.skyline_fan(objects,(0.,0.),0.,"test";illumination=0.)["features"])
    w=LW.world(true);actor=first(LW.IDS);w.positions[actor]=(0.,0.)
    yaw=Dict(a=>0. for a in LW.IDS)
    food=[(x=0.,z=8.,stock=1)]
    @test length(LW.perceive_movement(w,actor,yaw,food,[1];illumination=1.).visible)==1
    @test isempty(LW.perceive_movement(w,actor,yaw,food,[1];illumination=0.).visible)
    @test LW.home_observation(w,actor,yaw,(0.,8.);range=12,illumination=0.)===nothing
    # Actual predator visual adapter: same target/geometry, only ambient light differs.
    s,ps=animal_trial_world();empty!(s.world.obstacles);s.world.grass.=0
    s.alive.=false;s.alive[1]=true
    p=ps[1];p.visual.body.x=0.;p.visual.body.z=0.;p.visual.body.heading=0.;p.visual.gaze=0.
    s.animals.x[1]=12.;s.animals.z[1]=0.;p.visual.previous_prey[1]=(11.,0.)
    function seen_count(light)
        p.visual.body.state=P.SEARCH;p.visual.body.target=0;p.visual.gaze=0.
        p.visual.previous_prey[1]=(11.,0.)
        observed=Ref(0)
        G.configured_wildlife_predator_plan!(trial_proxy(s,p),0;illumination=light,
            local_planner=(proxy,observations,t)->(observed[]=length(observations);true))
        observed[]
    end
    @test seen_count(1.)==1
    @test seen_count(0.)==0
    # Actual rabbit adapter, moving predator ahead at distance 7.
    function rabbit_seen(light)
        sw,preds=animal_trial_world();empty!(sw.world.obstacles);sw.world.grass.=0
        sw.alive.=false;sw.alive[1]=true
        sw.animals.x[1]=0.;sw.animals.z[1]=0.;sw.animals.heading[1]=0.;sw.gaze[1]=0.
        preds[1].visual.body.x=7.;preds[1].visual.body.z=0.;preds[1].visual.previous_position=(6.,0.)
        G.prepare!(sw,Tuple{Float64,Float64}[],0;additional_predators=[preds[1].visual],illumination=light)
        sw.seen_actor[1]
    end
    @test rabbit_seen(1.)==1
    @test rabbit_seen(0.)==0
end
@testset "light transition invalidates distant visual prediction" begin
    state=LW.skyline_state()
    sample_day()=LW.D("coverage"=>"complete","source"=>"day","features"=>Any[LW.D("color"=>"red","azimuth"=>[-5.,5.],"range_band"=>"far","elevation"=>15)])
    sample_night()=LW.D("coverage"=>"complete","source"=>"night","features"=>Any[])
    LW.interval_skyline!(sample_day,state,nothing,0,"0";enabled=true,illumination=1.)
    receipt=LW.D("forward"=>.1,"right"=>0.,"yaw"=>0.,"after_us"=>1_000_000)
    observed=LW.interval_skyline!(sample_night,state,receipt,1_000_000,"1";enabled=true,illumination=0.)
    @test isempty(observed["features"]) && observed["coverage"]=="complete"
    @test state["interval_observation"]["illumination"]==0.
    w=LW.world(true);a,b=LW.IDS[1:2]
    w.positions[a]=(0.,0.);w.positions[b]=(0.,6.)
    for other in LW.IDS[3:end];w.positions[other]=(100.,100.);end
    @test length(LW.social_sight(w,a,0.,0;illumination=1.)["peers"])==1
    @test isempty(LW.social_sight(w,a,0.,0;illumination=0.)["peers"])
end
