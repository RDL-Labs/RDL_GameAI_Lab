# Continue the completed five-day macro/private-trade trial to total day 30.
using JSON3, SHA
length(ARGS)==2 || error("usage: trade_continue30.jl BASE5 NEW_OUTPUT")
const continuation_base=abspath(ARGS[1])
const continuation_output=abspath(ARGS[2])
const continuation_repo=normpath(joinpath(@__DIR__,"../.."))
JSON3.read(read(joinpath(continuation_base,"completed.json"),String)).days==5 || error("five-day base required")
isfile(joinpath(continuation_base,"checkpoints/day-005.jls")) || error("checkpoint missing")
ispath(continuation_output) && error("fresh output required")
# The shared continuation runner overlays these files. Refuse silent code changes.
for relative in ("lw/decision/item_social.jl","lw/decision/item_exchange_memory.jl",
    "lw/decision/gradient_trace.jl","lw/decision/trade_communication.jl",
    "lw/decision/food_exchange.jl","lw/configured_paths/voice_request.jl",
    "perception/sound_level.jl","lw/decision/task_focus.jl")
    sha256(read(joinpath(continuation_repo,"src",relative)))==sha256(read(joinpath(continuation_base,"source/src",relative))) || error("changed overlay: $relative")
end
ENV["RDL_LEARNED_TRADE"]="1";ENV["RDL_WANT_VOICE"]="1"
ENV["RDL_ALTERNATE_E"]="0";ENV["RDL_NO_GESTURES"]="0"
ENV["RDL_COHORT_DAYS"]="25"
println("Continuing macro/private-trade day 5 -> 30; 5 actors, private stores, existing individual supply; no retraining, no API.")
flush(stdout)
empty!(ARGS);append!(ARGS,["continue",continuation_base,continuation_output])
include(joinpath(continuation_repo,"experiments/simple_language/cohort_run.jl"))
