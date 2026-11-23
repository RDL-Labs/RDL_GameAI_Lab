# Fresh, ordinary MB-only private-warehouse communication trial.
# Existing fixed tasting, daily supply, language/channel scaffolds remain explicit.
using JSON3
2<=length(ARGS)<=3 || error("usage: private_supplier_run.jl BASE NEW_OUTPUT [DAYS=10]")
const PRIVATE_DAYS=length(ARGS)==3 ? parse(Int,ARGS[3]) : 10
PRIVATE_DAYS>=3 || error("at least three training days")
const PRIVATE_BASE=abspath(ARGS[1]);const PRIVATE_OUTPUT=abspath(ARGS[2])
ENV["RDL_LEARNED_TRADE"]="1";ENV["RDL_WANT_VOICE"]="1"
ENV["RDL_ALTERNATE_E"]="0";ENV["RDL_NO_GESTURES"]="0"
runner=read(joinpath(@__DIR__,"cohort_run.jl"),String)
runner=replace(runner,"const HERE=@__DIR__"=>"const HERE="*repr(@__DIR__))
needle="MODE==\"train\" ? 3 : STARTDAY"
@assert length(findall(needle,runner))==1
runner=replace(runner,needle=>"MODE==\"train\" ? $PRIVATE_DAYS : STARTDAY")
empty!(ARGS);append!(ARGS,["train",PRIVATE_BASE,PRIVATE_OUTPUT])
include_string(Main,runner,joinpath(@__DIR__,"private_supplier_generated.jl"))
