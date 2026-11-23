using JSON3,Serialization,SHA
root=abspath(ARGS[1]);out=abspath(ARGS[2]);day=parse(Int,ARGS[3]);mkpath(out)
include(joinpath(root,"source/src/lw/LW.jl"))
include("local_probe.jl")
struct RefusalCaptured <: Exception end
source=read(joinpath(root,"source/src/lw/decision/social_response.jl"),String)
part=first(split(source,"# Fulfil"))
Base.include_string(LW,replace(part,"function experienced_response("=>"function captured_original_response("))
function capture_response(obs,records,pressure,owner,seed;kwargs...)
 before=deepcopy((obs=obs,records=records,pressure=pressure,owner=owner,seed=seed,kwargs=(;kwargs...)))
 decision,trace=LW.captured_original_response(obs,records,pressure,owner,seed;kwargs...)
 if decision[1]=="refuse" && get(before.kwargs,:available_food,false) && trace!==nothing
  serialize(joinpath(out,"refusal-input.jls"),before)
  write(joinpath(out,"original.json"),JSON3.write((decision=decision,trace=trace)))
  throw(RefusalCaptured())
 end
 decision,trace
end
Base.include_string(LW,"experienced_response(args...;kwargs...)=Main.capture_response(args...;kwargs...)")
# Replace exact positional signature too, to supersede the existing method.
Base.include_string(LW,"experienced_response(obs,records,pressure,owner,seed;kwargs...)=Main.capture_response(obs,records,pressure,owner,seed;kwargs...)")
input=JSON3.read(read(joinpath(root,"run/input.json"),String),Dict{String,Any});input["config"]["days"]=day
try
 LW.run_integrated(JSON3.read(JSON3.write(input));resume_from=joinpath(root,"run/checkpoints/day-"*lpad(day-1,3,'0')*".jls"))
catch err
 err isa RefusalCaptured || rethrow()
end
isfile(joinpath(out,"refusal-input.jls")) || error("No food-available refusal found")
f=deserialize(joinpath(out,"refusal-input.jls"))
lex=LocalLexicon();local_seed!(lex,"どんぐり",3)
interpretation=local_interpret(lex,"どんぐり、ちょうだい")
@assert interpretation.status==:request
# Local interpretation adapter, not a hidden sender-intent tag.
# Keep the historical context/MB/seed; availability is assumed for this bridge probe.
obs=deepcopy(f.obs);obs["messages"][1]["kind"]="request"
original=LW.captured_original_response(deepcopy(f.obs),deepcopy(f.records),deepcopy(f.pressure),f.owner,f.seed;deepcopy(f.kwargs)...)
translated=LW.captured_original_response(obs,deepcopy(f.records),deepcopy(f.pressure),f.owner,f.seed;deepcopy(f.kwargs)...)
@assert original==translated
@assert translated[1][1]=="refuse"
@assert local_interpret(LocalLexicon(),"どんぐり、ちょうだい").status==:unknown_name
write(joinpath(out,"comparison.json"),JSON3.write((source=root,day=day,owner=f.owner,seed=f.seed,
 expression="どんぐり、ちょうだい",interpretation=interpretation,decision=translated[1],trace=translated[2],
 same_response=true,unknown_name_blocks=true,scope="historical MB and context, seeded language; named item availability assumed, no physical execution")))
println(read(joinpath(out,"comparison.json"),String))
