using Serialization,JSON3,Random,Test
include(joinpath(@__DIR__,"predator_generations.jl"))
include(joinpath(@__DIR__,"../../src/lw/configured_paths/raptor_trial.jl"))
include(joinpath(@__DIR__,"../../src/lw/configured_paths/predator_population_exchange.jl"))
saved=deserialize("C:/Users/ken_m/Documents/Codex/rabbit-fresh3000-20261110/run-v2/checkpoints/day-257.jls")
s=saved.world;c=saved.cohort;m=PredatorPopulationExchange(length(c.predators));old=c.predators[1];oldcapt=old.visual.body.captures
configured_predator_replacement_update!(s,c,m,s.ticks)
@test length(c.predators)==2
@test !old.alive && old.visual.body.captures==oldcapt
@test c.predators[2].alive && c.predators[2].visual.body.captures==0
@test isempty(c.minds[2].places) && isempty(c.minds[2].records)
@test c.predators[2].food==PREDATOR_ANIMAL_TRIAL.initial_food
@test length(c.physiology)==length(c.pursuits)==length(m.present)==2
@test count(e->e.event=="replacement_death",m.events)==1
configured_predator_replacement_update!(s,c,m,s.ticks)
@test length(c.predators)==2
configured_predator_replacement_update!(s,c,m,s.ticks+17280)
@test length(c.predators)==2
io=IOBuffer();serialize(io,(s=s,c=c,m=m));seekstart(io);copy=deserialize(io)
@test copy.c.predators[2].alive && !copy.c.predators[1].alive
println("replacement checks: 10 PASS")
