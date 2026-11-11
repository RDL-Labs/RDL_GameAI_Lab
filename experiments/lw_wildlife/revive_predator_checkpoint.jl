# One-shot, user-authorized intervention. No automatic resurrection in simulation.
using Serialization,JSON3,Random,Test
include(joinpath(@__DIR__,"predator_generations.jl"))
include(joinpath(@__DIR__,"../../src/lw/configured_paths/raptor_trial.jl"))
source=ARGS[1];destination=ARGS[2];saved=deserialize(source)
p=only(saved.cohort.predators);phys=only(saved.cohort.physiology)
@test !p.alive && p.food==0
before=(position=(p.visual.body.x,p.visual.body.z),food=p.food,eaten=p.eaten,spent=p.spent,captures=p.visual.body.captures)
amount=PREDATOR_ANIMAL_TRIAL.initial_food-p.food
p.alive=true;p.food+=amount;p.eaten+=amount;p.mode=:idle
# Legacy balance counts all received food in eaten. Record external input separately;
# never interpret this increment as successful hunting or a rabbit consumed.
mind=only(saved.cohort.minds)
mind.estimates["experiment_external_food"]=get(mind.estimates,"experiment_external_food",0.)+amount
body=phys.body;phys.body=LW.Body(body.burst,body.strain,p.food,body.damage)
@test p.visual.body.captures==before.captures
@test p.spent==before.spent
@test abs(trial_predator_report(p).balance_residual)<.01
serialize(destination,saved)
verified=deserialize(destination)
@test only(verified.cohort.predators).alive
@test only(verified.cohort.physiology).body.reserve==p.food
record=(action="one_time_predator_revival",day=div(saved.world.ticks,17280),source=source,checkpoint=destination,external_food=amount,before=before,after_food=p.food,legacy_eaten_includes_external=true,preserved="position, memories, RNG, fatigue, damage, prey, grass, captures; interrupted death trial remains ended")
write(joinpath(dirname(dirname(destination)),"revival.json"),JSON3.write(record));println(JSON3.write(record))
