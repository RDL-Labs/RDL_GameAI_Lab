include("animals_only.jl")
include("../../src/lw/configured_paths/raptor_trial.jl")
function raptor_checks()
    input=JSON3.read(read(joinpath(@__DIR__,"../../outputs/lw-rabbit-family-30d-20261106/input.json"),String))
    s,predators=animal_trial_world(;adult_rabbits=150)
    bird=configured_raptor(s,input.scene)
    @testset "raptor lifecycle and accounting" begin
        configured_raptor_population!(bird,149,0);@test !bird.present
        configured_raptor_population!(bird,150,0);@test bird.present && bird.arrivals==1
        configured_raptor_population!(bird,101,17280);@test bird.mode==:arrive
        configured_raptor_population!(bird,100,17280);@test bird.mode==:depart
        bird.destination=configured_raptor_edge(s.world,(bird.visual.body.x,bird.visual.body.z))
        for t in 1:200;configured_raptor_step!(bird,s,TrialPredator[],t);end
        @test !bird.present && bird.departures==1
        configured_raptor_population!(bird,149,34560);@test !bird.present
        configured_raptor_population!(bird,150,34560);@test bird.arrivals==2
        bird.mode=:rest;bird.due=1000;bird.food=100.
        scans=bird.scans
        for t in 1:500;configured_raptor_step!(bird,s,TrialPredator[],t);end
        @test bird.scans==scans && bird.mode==:rest
        @test bird.food<100
        # Target moved away during flight: no teleport capture.
        bird.target=1;bird.visual.body.x=s.animals.x[1]+10;bird.visual.body.z=s.animals.z[1]
        configured_raptor_capture!(bird,s,0);@test bird.captures==0 && s.alive[1]
        # Burrow young remain inaccessible even at contact.
        young=findfirst(i->G.configured_rabbit_in_burrow(s,i,0),eachindex(s.alive))
        @test young!==nothing
        bird.target=young;bird.visual.body.x=s.animals.x[young];bird.visual.body.z=s.animals.z[young]
        configured_raptor_capture!(bird,s,0);@test s.alive[young]
        # Open adult target, deterministic seeded repeated independent attempts.
        empty!(s.world.obstacles);s.world.traits.density.=0.
        bird.target=1;bird.visual.body.x=s.animals.x[1];bird.visual.body.z=s.animals.z[1]
        for attempt in 1:100
            bird.target=1;configured_raptor_capture!(bird,s,0)
            bird.captures>0 && break
        end
        @test bird.captures==1 && !s.alive[1] && bird.mode==:eat
        meal=bird.meal;food=bird.food
        configured_raptor_step!(bird,s,TrialPredator[],1)
        @test bird.meal<meal && bird.food>food
        # Ground predator interrupts food intake; leftovers are accounted separately.
        predator=first(predators);predator.visual.body.x=bird.visual.body.x;predator.visual.body.z=bird.visual.body.z
        configured_raptor_step!(bird,s,predators,2)
        @test bird.mode==:return && bird.interrupted_meals==1 && bird.remains>0
        @test bird.eaten+bird.remains≈meal
        bird.target=1;configured_raptor_capture!(bird,s,3)
        @test bird.captures==1 # no duplicate death
        # Serialized state/RNG continue identically.
        buffer=IOBuffer();serialize(buffer,bird);seekstart(buffer);copy_bird=deserialize(buffer)
        for t in 4:1000
            configured_raptor_step!(bird,s,TrialPredator[],t)
            configured_raptor_step!(copy_bird,s,TrialPredator[],t)
        end
        @test configured_raptor_report(bird)==configured_raptor_report(copy_bird)
    end
    # Actual prepare/advance loop, moving prey, burrows, births and predation ledger.
    s,predators=animal_trial_world(;adult_rabbits=150);empty!(predators)
    bird=configured_raptor(s,input.scene);policy=H.RabbitApproachPolicy()
    configured_raptor_population!(bird,count(s.alive),0)
    bird.visual.body.x,bird.visual.body.z=configured_raptor_edge(s.world,bird.destination)
    timing=@timed for t in 0:17279
        animal_trial_prepare!(s,predators,t;raptor=bird,motion_speed=true)
        animal_trial_advance!(s,predators,t;grazing_policy=policy)
        configured_raptor_step!(bird,s,predators,t)
    end
    report=animal_trial_report(s,predators;raptor=bird)
    @test report.rabbits.alive+s.deaths+bird.captures==length(s.alive)
    @test bird.scans>0 && bird.attempts>0
    result=(seconds=timing.time,rabbits=report.rabbits.alive,raptor=configured_raptor_report(bird))
    println(JSON3.write(result))
    write(joinpath(@__DIR__,"evidence/raptor-smoke.json"),JSON3.write(result))
end
raptor_checks()
