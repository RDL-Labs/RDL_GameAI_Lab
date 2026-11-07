# Read-only ledger/size reconstruction from frozen code and final checkpoint.
# No simulation and no behavior changes; accepted/discarded amounts remain aggregate.
using JSON3, Serialization, Test
const food_run=abspath(ARGS[1])
include(joinpath(food_run,"source/experiments/lw_wildlife/animals_only.jl"))
const food_config=JSON3.read(read(joinpath(food_run,"conditions.json"),String))
const food_saved=deserialize(joinpath(food_run,"checkpoints","day-"*lpad(food_config.days,3,'0')*".jls"))
const food_world=food_saved.state[:wildlife]
const food_cohort=food_saved.state[:predator_cohort]
const food_rows=Any[]
for (actor,predator) in enumerate(food_cohort.predators)
    captures=filter(e->e.kind=="capture",predator.visual.events)
    reconstructed=map(captures) do event
        # Rabbits advance before predator consumption: height uses tick+1.
        age=(event.tick+1-food_world.life.born[event.id])/G.RABBIT_LIFE.day_ticks
        height=G.RABBIT_LIFE.infant_height+(G.RABBIT_LIFE.adult_height-G.RABBIT_LIFE.infant_height)*clamp(age/G.RABBIT_LIFE.maturity_days,0.,1.)
        fraction=clamp((height/G.RABBIT_LIFE.adult_height)^3,PREDATOR_ANIMAL_TRIAL.minimum_size_fraction,1.)
        (tick=event.tick,day=div(event.tick,17280)+1,prey=event.id,age_days=age,
            fraction=fraction,gross_food=PREDATOR_ANIMAL_TRIAL.adult_food*1.5*fraction)
    end
    gross=sum(r.gross_food for r in reconstructed;init=0.)
    live_ticks=sum(n for (mode,n) in predator.ticks if mode!=:dead;init=0)
    basal=live_ticks*PREDATOR_ANIMAL_TRIAL.daily_food/PREDATOR_ANIMAL_TRIAL.day_ticks
    movement=predator.visual.body.distance*PREDATOR_ANIMAL_TRIAL.move_food
    @test length(captures)==predator.visual.body.captures
    @test isapprox(gross,predator.eaten+predator.discarded;atol=1e-6)
    @test isapprox(PREDATOR_ANIMAL_TRIAL.initial_food+predator.eaten,predator.spent+predator.food;atol=1e-6)
    push!(food_rows,(actor=actor,alive=predator.alive,life_days=live_ticks/17280,
        food=predator.food,captures=length(captures),full_size=count(r->r.fraction==1,reconstructed),
        minimum_size=count(r->r.fraction==PREDATOR_ANIMAL_TRIAL.minimum_size_fraction,reconstructed),
        gross=gross,accepted=predator.eaten,discarded=predator.discarded,spent=predator.spent,
        basal_nominal=basal,movement=movement,distance=predator.visual.body.distance,
        rest_and_final_tick_rounding=predator.spent-basal-movement,meals=reconstructed))
end
write(ARGS[2],JSON3.write((source=food_run,actors=food_rows,
    note="Frozen-rule reconstruction; exact gross matches eaten+discarded. Accepted/discarded are total ledgers, not per-capture reconstructions. Nominal basal includes full final alive tick; death may clip its expense.")))
println(JSON3.write([(; (k=>v for (k,v) in pairs(row) if k!=:meals)...) for row in food_rows]))
