# Local fresh five-day run: three tasting days + two interaction days, A-D MB, E API.
using JSON3
length(ARGS)==2 || error("usage: api_agent_run.jl BASE NEW_OUTPUT")
const API_BASE=abspath(ARGS[1]); const API_OUTPUT=abspath(ARGS[2])
ispath(API_OUTPUT) && error("fresh output required")
if !haskey(ENV,"OPENAI_API_KEY")
    ENV["OPENAI_API_KEY"]=strip(read(`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('OPENAI_API_KEY','User')"`,String))
end
isempty(ENV["OPENAI_API_KEY"]) && error("API key missing")
ENV["RDL_LEARNED_TRADE"]="1";ENV["RDL_WANT_VOICE"]="0"
ENV["RDL_ALTERNATE_E"]="0";ENV["RDL_NO_GESTURES"]="0"
runner=read(joinpath(@__DIR__,"cohort_run.jl"),String)
runner=replace(runner,"const HERE=@__DIR__"=>"const HERE="*repr(@__DIR__),"MODE==\"train\" ? 3 : STARTDAY"=>"MODE==\"train\" ? 5 : STARTDAY")
injection=read(joinpath(@__DIR__,"api_agent_instrument.jl"),String)
marker="include(joinpath(OUTPUT,\"source/integrations/lightweight_julia/native.jl\"))"
@assert length(findall(marker,runner))==1
runner=replace(runner,marker=>injection*"\n"*marker)
empty!(ARGS);append!(ARGS,["train",API_BASE,API_OUTPUT])
include_string(Main,runner,joinpath(@__DIR__,"api_agent_generated.jl"))
write(joinpath(API_OUTPUT,"api-summary.json"),JSON3.write((calls=CONFIGURED_API_CALLS,memory=CONFIGURED_API_MEMORY[],actor=CONFIGURED_API_AGENT.actor,model=CONFIGURED_API_AGENT.model)))

