include("animals_only.jl")
@testset "optional crossing, H breadth, local credit and water cost" begin
    s,predators=animal_trial_world();p=predators[1];b=p.visual.body;w=s.world
    empty!(w.obstacles)
    z=0.;river=12+5sin((z-6)/22+w.phase);b.x=river-3;b.z=z;p.food=400.
    mind=PredatorMind(1);phys=PredatorPhysiology(p);rival=(actor=nothing,distance=Inf)
    off=predator_candidates(mind,p,rival,nothing,1;physiology=phys,world=w)
    @test !any(c->c["action"]==:cross_river,off)
    mind.estimates["crossing_enabled"]=1.
    rows=predator_candidates(mind,p,rival,nothing,1;physiology=phys,world=w)
    index=findfirst(c->c["action"]==:cross_river,rows);@test index!==nothing
    crossing=rows[index];@test crossing["priority"]<rows[1]["priority"]
    low=LW.method_distribution(mind.loop,rows)[index]
    mind.loop.H=10.;high=LW.method_distribution(mind.loop,rows)[index]
    @test high>low
    # Water is now traversable terrain with a cost, not an absolute barrier.
    @test H.clear(w,(river-1.,z),(river+1.,z))
    @test H.configured_rabbit_terrain_distance(w,(river-1.,z),(river+1.,z))>2.
    # Select only this candidate for the execution test, not as a production rule.
    mind.selected=LW.choose_method!(mind.loop,[crossing],1)
    mind.trial=LW.action_trial(1,crossing["method"],crossing["question"],crossing["forecast"])
    mind.start_food=p.food;mind.start_spent=p.spent;mind.start_eaten=p.eaten;mind.start_capture=b.captures
    target=crossing["target"];parent_H=mind.loop.H;capture_before=b.captures
    extra=0.
    for t in 1:100
        hypot(b.x-target[1],b.z-target[2])<=PREDATOR_CROSSING.arrival_radius && break
        b.heading=atan(target[2]-b.z,target[1]-b.x)
        extra+=configured_crossing_step!(w,b,PREDATOR_CROSSING.land_speed)
    end
    @test b.x>river && !crossing_water(w,(b.x,b.z))
    @test extra>0
    predator_mind_close!(mind,p,rival,101;physiology=phys)
    @test mind.records[end]["status"]=="achieved"
    @test mind.loop.H==parent_H && b.captures==capture_before && isempty(mind.places)
    # Water-only transaction accounts extra movement cost once and mirrors reserve.
    b.x=river;b.z=z;b.heading=0.;p.mode=:cross_river
    before=p.food;configured_trial_advance!(s,p,102;physiology=phys)
    @test before-p.food≈PREDATOR_ANIMAL_TRIAL.daily_food/17280+PREDATOR_ANIMAL_TRIAL.move_food*PREDATOR_CROSSING.swim_speed*PREDATOR_CROSSING.swim_move_multiplier
    @test phys.body.reserve==p.food
    # Solid obstacles remain impassable even with swim capability.
    push!(w.obstacles,H.RDLMigrationProbe.Circle(b.x,b.z,3.))
    origin=(b.x,b.z);configured_crossing_step!(w,b,.22)
    @test (b.x,b.z)==origin
    empty!(w.obstacles);p.food=.001
    rows=Any[];configured_crossing_candidate!(rows,mind,p,w;physiology=phys)
    @test isempty(rows)
end
