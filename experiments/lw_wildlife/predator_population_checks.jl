using Test,Random,Serialization
include("predator_generations.jl")
include("../../src/lw/configured_paths/predator_population_exchange.jl")
@testset "world predator immigration and emigration" begin
    @test configured_predator_population_target.([0,99,100,199,200,300])==[0,0,1,1,2,3]
    @test configured_predator_population_target.([49,50,51,99,100],1)==[0,0,1,1,1]
    @test configured_predator_population_target.([149,150,151,199,200],2)==[1,1,2,2,2]
    wildlife,predators=animal_trial_world(;adult_rabbits=295)
    cohort=(predators,minds=PredatorMind.(1:2),local_hunts=[LocalHunt(i;probabilistic_capture=true) for i in 1:2],
        pursuits=PredatorPursuit.(1:2),physiology=PredatorPhysiology.(predators),
        scents=PredatorScentWorld(2),prey_scents=PreyScentWorld(2;cautious=true))
    migration=PredatorPopulationExchange(2)
    @test count(wildlife.alive)==300
    configured_predator_population_update!(wildlife,cohort,migration,0)
    @test length(predators)==3
    @test all(migration.present)
    @test H.clear(wildlife.world,(predators[3].visual.body.x,predators[3].visual.body.z),(predators[3].visual.body.x,predators[3].visual.body.z))
    @test isempty(cohort.minds[3].places)
    @test length(cohort.scents.memory)==length(cohort.prey_scents.observed)==3
    configured_predator_population_update!(wildlife,cohort,migration,0)
    @test length(migration.events)==1
    original_alive=copy(wildlife.alive)
    wildlife.alive.=false
    cohort.minds[1].trial=LW.action_trial("test","test","food",100.)
    configured_predator_population_update!(wildlife,cohort,migration,1)
    @test all(migration.present) # No per-tick adjustment.
    configured_predator_population_update!(wildlife,cohort,migration,17280)
    @test !any(migration.present)
    @test cohort.minds[1].trial["status"]=="interrupted"
    @test all(p->p.alive,predators) # Departure is not biological death.
    @test configured_predator_population_report(cohort,migration,0).deaths==0
    wildlife.alive.=original_alive
    archived=deepcopy((predators,cohort.minds,cohort.scents.deposits))
    for tick in 0:29
        animal_trial_prepare!(wildlife,predators,tick;minds=cohort.minds,scents=cohort.scents,
            prey_scents=cohort.prey_scents,local_hunts=cohort.local_hunts,physiology=cohort.physiology,
            pursuits=cohort.pursuits,present=migration.present)
        animal_trial_advance!(wildlife,predators,tick;minds=cohort.minds,scents=cohort.scents,
            prey_scents=cohort.prey_scents,local_hunts=cohort.local_hunts,physiology=cohort.physiology,
            pursuits=cohort.pursuits,present=migration.present)
    end
    @test [p.food for p in predators]==[p.food for p in archived[1]]
    @test [p.visual.body.captures for p in predators]==[p.visual.body.captures for p in archived[1]]
    @test [m.loop.sequence for m in cohort.minds]==[m.loop.sequence for m in archived[2]]
    @test cohort.scents.deposits==archived[3]
    @test all(iszero,wildlife.overrides) # Off-map predators do not trigger rabbit alarm.
    configured_predator_population_update!(wildlife,cohort,migration,34560)
    @test length(predators)==6
    @test migration.present==BitVector([false,false,false,true,true,true])
    predators[4].alive=false
    configured_predator_population_update!(wildlife,cohort,migration,51840)
    @test length(predators)==7
    report=configured_predator_population_report(cohort,migration,count(wildlife.alive))
    @test (report.residents,report.deaths,report.departures)==(3,1,3)
    mktemp() do path,io
        close(io);serialize(path,(world=wildlife,cohort,migration))
        saved=deserialize(path)
        configured_predator_population_update!(saved.world,saved.cohort,saved.migration,51840)
        @test saved.migration.events==migration.events
        @test rand(saved.migration.rng)==rand(migration.rng)
    end
    # Consecutive day-boundary updates: no immigration/emigration churn near 100.
    for (step,(rabbit_count,expected_residents)) in enumerate([
        (251,3),(250,2),(199,2),(150,1),(99,1),(100,1),(99,1),
        (51,1),(50,0),(99,0),(100,1)])
        wildlife.alive.=false;wildlife.alive[1:rabbit_count].=true
        previous_events=length(migration.events)
        previous_residents=count(i->migration.present[i] && predators[i].alive,eachindex(predators))
        configured_predator_population_update!(wildlife,cohort,migration,(3+step)*17280)
        @test configured_predator_population_report(cohort,migration,rabbit_count).residents==expected_residents
        @test length(migration.events)-previous_events==abs(expected_residents-previous_residents)
    end
end
