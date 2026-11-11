using Serialization,JSON3,Random
const sexaudit_root="C:/Users/ken_m/Documents/Codex/raptor-foodresolved2336-360d-20261110/run"
include(joinpath(sexaudit_root,"source/experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(sexaudit_root,"source/src/lw/configured_paths/raptor_trial.jl"))
rows=Any[]
for day in (1,90,110,217,264,265,300,360)
 saved=deserialize(joinpath(sexaudit_root,"checkpoints/day-"*lpad(day,3,'0')*".jls"));s=saved.world;a=s.animals;l=s.life
 west(i)=a.x[i]<12+5sin((a.z[i]-6)/22+s.world.phase)
 ids=[i for i in eachindex(s.alive) if s.alive[i] && west(i)]
 roster=[(id=i,sex=l.sex[i]==1 ? "female" : "male",age=(s.ticks-l.born[i])/17280,mother=l.mother[i],due=l.due[i],position=(a.x[i],a.z[i]),energy=a.energy[i]) for i in ids]
 push!(rows,(day=day,roster=roster))
end
write(joinpath(@__DIR__,"evidence/west-sex-resolved360.json"),JSON3.write(rows))
println(JSON3.write(rows))
