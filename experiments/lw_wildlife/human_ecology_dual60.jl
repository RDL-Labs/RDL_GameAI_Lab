# OUTPUT HUMAN_SEED WILDLIFE_SEED [DAYS=60]; initial state, no inherited MBs.
using JSON3
length(ARGS) in (3,4) || error("OUTPUT HUMAN_SEED WILDLIFE_SEED [DAYS=60]")
human_ecology_output=abspath(ARGS[1])
human_ecology_seed=parse(Int,ARGS[2]);wildlife_seed=parse(Int,ARGS[3])
human_ecology_days=length(ARGS)==4 ? parse(Int,ARGS[4]) : 60
1<=human_ecology_days<=60 || error("days must be 1..60")
ispath(human_ecology_output) && error("fresh output required")
mkpath(human_ecology_output)
human_ecology_input=JSON3.read(read(joinpath(@__DIR__,"candidate_longrun_input.json"),String),Dict{String,Any})
human_ecology_input["config"]["seed"]=human_ecology_seed
human_ecology_input["scene"]["wildlife"]["seed"]=wildlife_seed
human_ecology_input["scene"]["rho_box_boundaries"]=true
human_ecology_input_path=joinpath(human_ecology_output,"input.json")
write(human_ecology_input_path,JSON3.write(human_ecology_input))
empty!(ARGS)
append!(ARGS,[human_ecology_input_path,"none",joinpath(human_ecology_output,"run"),string(human_ecology_days),"0","true","true","true","batch_cpu","2"])
include("humans_learned_predators.jl")
