# Execution wrapper only; retain the established animal-only world and fixed rules.
# OUTPUT SEED [DAYS=360] [COMPOSITION=true] [RABBIT_COMPOSITION=true]. Seed changes wildlife initialization, not every subsystem RNG.
using JSON3
length(ARGS) in (2,3,4,5) || error("OUTPUT SEED [DAYS=360] [COMPOSITION=true] [RABBIT_COMPOSITION=true]")
ecology_output=abspath(ARGS[1])
ecology_seed=parse(Int,ARGS[2])
ecology_days=length(ARGS)>=3 ? parse(Int,ARGS[3]) : 360
ecology_composition=length(ARGS)>=4 ? parse(Bool,ARGS[4]) : true
ecology_rabbit_composition=length(ARGS)>=5 ? parse(Bool,ARGS[5]) : true
1<=ecology_days<=360 || error("days must be 1..360")
ispath(ecology_output) && error("fresh output required")
mkpath(ecology_output)
ecology_input=JSON3.read(read(joinpath(@__DIR__,"ecology_dual_input.json"),String),Dict{String,Any})
ecology_input["scene"]["wildlife"]["seed"]=ecology_seed
ecology_input_path=joinpath(ecology_output,"input.json")
write(ecology_input_path,JSON3.write(ecology_input))
write(joinpath(ecology_output,"request.json"),JSON3.write((rabbit_composition=ecology_rabbit_composition,composition=ecology_composition,days=ecology_days,seed=ecology_seed,humans=0,scat=true,ground_prey_nutrition=.5,raptor_prey_nutrition=.5,backend="batch_cpu",source_policy="current checkout; run/source is the frozen ecology implementation",fixed_rules="predator daily replacement; raptor arrival>=150 departure<=100",threads=Threads.nthreads())))
empty!(ARGS)
append!(ARGS,[ecology_input_path,"none",joinpath(ecology_output,"run"),string(ecology_days),"true","1","1.5","none","true","batch_cpu","baseline","full","distributed","layered","replace","0.5","true","150","false","true","0.5",string(ecology_composition),string(ecology_rabbit_composition)])
include("crossing_longrun.jl")
