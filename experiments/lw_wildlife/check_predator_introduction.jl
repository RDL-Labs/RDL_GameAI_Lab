# Read-only: PRIOR_CHECKPOINT INTRODUCTION_RUN. Verify initialization and smoke completion.
using Serialization,JSON3,Test
include(joinpath(ARGS[2],"source/experiments/lw_wildlife/predator_generations.jl"))
function same_state(left,right)
    typeof(left)==typeof(right) || return false
    isequal(left,right) && return true
    if left isa AbstractArray
        axes(left)==axes(right) || return false
        return all(same_state(left[i],right[i]) for i in eachindex(left))
    elseif left isa AbstractDict
        Set(keys(left))==Set(keys(right)) || return false
        return all(same_state(left[k],right[k]) for k in keys(left))
    elseif isstructtype(typeof(left)) && fieldcount(typeof(left))>0
        return all(same_state(getfield(left,k),getfield(right,k)) for k in fieldnames(typeof(left)))
    end
    false
end
expected_predators=length(ARGS)>=3 ? parse(Int,ARGS[3]) : 2
prior=deserialize(ARGS[1])
introduced=deserialize(joinpath(ARGS[2],"checkpoints/day-000.jls"))
completion=JSON3.read(read(joinpath(ARGS[2],"completed.json"),String))
last_saved=deserialize(joinpath(ARGS[2],"checkpoints/day-"*lpad(completion.days,3,'0')*".jls"))
@testset "predator introduction preserves existing world" begin
    @test isempty(prior.cohort.predators)
    @test length(introduced.cohort.predators)==expected_predators
    @test same_state(prior.world,introduced.world)
    @test same_state(prior.cohort.rabbit_approach,introduced.cohort.rabbit_approach)
    @test all(p->p.alive && p.food==PREDATOR_ANIMAL_TRIAL.initial_food,introduced.cohort.predators)
    @test all(p->p.visual.body.captures==0,introduced.cohort.predators)
    @test completion.verified
    @test completion.start_day==div(prior.world.ticks,17280)
    @test completion.end_day==completion.start_day+completion.days
    @test last_saved.world.ticks==prior.world.ticks+completion.days*17280
end
