using Serialization,JSON3,Random,Test
include("predator_generations.jl")
include("../../src/lw/configured_paths/predator_population_exchange.jl")
@testset "replacement rabbit threshold" begin
    for body_constructor in (PredatorPhysiology,ComposedPredatorPhysiology)
    s,ps=animal_trial_world(adult_rabbits=150);resize!(ps,1)
    c=(predators=ps,minds=[PredatorMind(1)],local_hunts=[LocalHunt(1;probabilistic_capture=true)],
       pursuits=[PredatorPursuit(1)],physiology=body_constructor.(ps),
       scents=PredatorScentWorld(1),prey_scents=PreyScentWorld(1;cautious=true))
    m=PredatorPopulationExchange(1);ps[1].alive=false;ps[1].food=0.
    s.alive.=false;s.alive[1:99].=true
    configured_predator_replacement_update!(s,c,m,0)
    @test length(ps)==1
    @test count(e->e.event=="replacement_death",m.events)==1
    s.alive[100]=true
    configured_predator_replacement_update!(s,c,m,17280)
    @test length(ps)==2 && ps[2].alive
    @test ps[2].food==PREDATOR_ANIMAL_TRIAL.initial_food
    @test isempty(c.minds[2].places)
    configured_predator_replacement_update!(s,c,m,17280)
    @test length(ps)==2
    s.alive.=false
    configured_predator_replacement_update!(s,c,m,34560)
    @test ps[2].alive && m.present[2]
    ps[2].alive=false
    configured_predator_replacement_update!(s,c,m,51840)
    @test length(ps)==2
    @test count(e->e.event=="replacement_death",m.events)==2
    io=IOBuffer();serialize(io,(s,c,m));seekstart(io);s2,c2,m2=deserialize(io)
    s2.alive[1:100].=true
    configured_predator_replacement_update!(s2,c2,m2,69120)
    @test length(c2.predators)==3
    @test all(x->x isa body_constructor,c2.physiology)
    end
end
