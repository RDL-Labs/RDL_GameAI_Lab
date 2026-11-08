# Explicit migration: export FROZEN_RUN CHECKPOINT OUTPUT, then import EXPORT OUTPUT.
# Preserves old world/RNG; initializes unknown reserve history to neutral at migration time.
using Serialization,Test
mode=ARGS[1]
if mode=="export"
 include(joinpath(ARGS[2],"source/experiments/lw_wildlife/predator_generations.jl"))
 saved=deserialize(ARGS[3]);life=saved.world.life
 fields=NamedTuple{fieldnames(typeof(life))}(Tuple(getfield(life,k) for k in fieldnames(typeof(life))))
 saved.world.life=nothing
 ispath(ARGS[4]) && error("fresh output required")
 serialize(ARGS[4],(checkpoint=saved,life_fields=fields))
elseif mode=="import"
 include("predator_generations.jl")
 exported=deserialize(ARGS[2]);saved=exported.checkpoint;s=saved.world;n=length(s.alive)
 @assert !hasproperty(exported.life_fields,:reserve_balance)
 s.life=G.RabbitLife(values(exported.life_fields)...,copy(s.animals.energy),zeros(n),fill(s.ticks,n))
 ispath(ARGS[3]) && error("fresh output required")
 serialize(ARGS[3],saved)
 checked=deserialize(ARGS[3])
 @test checked.world.animals.energy==s.animals.energy
 @test checked.world.life.reserve_balance==zeros(n)
 @test checked.world.life.born==exported.life_fields.born
 @test checked.world.life.rng==exported.life_fields.rng
 println("MIGRATED ticks=",s.ticks," alive=",count(s.alive)," history=neutral (unknown)")
else
 error("expected export or import")
end
