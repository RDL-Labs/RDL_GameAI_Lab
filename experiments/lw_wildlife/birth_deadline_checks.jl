using Serialization,JSON3,Random,Test
include(joinpath(@__DIR__,"predator_generations.jl"))
include(joinpath(@__DIR__,"../../src/lw/configured_paths/raptor_trial.jl"))
const birth_root="C:/Users/ken_m/Documents/Codex/raptor-foodresolved2336-360d-20261110/run"
saved=deserialize(joinpath(birth_root,"checkpoints/day-001.jls"));s=saved.world;i=1890
birth_position=(s.animals.x[i],s.animals.z[i]);old_due=s.life.due[i];old_births=s.life.births;old_invested=s.life.invested[i];old_energy=s.animals.energy[i];old_alloc=length(s.alive)
@test old_due<s.ticks
@test !G.configured_rabbit_nest_allowed(s.world,birth_position)
G.rabbit_daily!(s,s.ticks)
children=collect(old_alloc+1:length(s.alive))
@test length(children)==5
@test s.life.births==old_births+5
@test s.life.due[i]==0
@test all(j->s.life.born[j]==s.ticks && s.initial_positions[j]==birth_position,children)
@test all(j->!G.configured_rabbit_in_burrow(s,j,s.ticks),children)
predator_view=(world=s.world,animals=s.animals,alive=s.alive,life=s.life,ticks=s.ticks)
@test all(j->!G.configured_rabbit_in_burrow(predator_view,j,s.ticks),children)
@test sum(s.animals.energy[children])≈old_invested
@test s.animals.energy[i]==old_energy
G.rabbit_daily!(s,s.ticks+17280)
@test s.life.births==old_births+5
result=(mother=i,scheduled_day=old_due/17280,resumed_day=s.ticks/17280,birth_position=birth_position,children=children,births_added=s.life.births-old_births,protected=false,investment_transferred=old_invested)
write(joinpath(@__DIR__,"evidence/birth-deadline-1890.json"),JSON3.write(result));println(JSON3.write(result))
