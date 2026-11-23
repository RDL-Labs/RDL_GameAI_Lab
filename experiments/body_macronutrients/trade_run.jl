# Five fresh days on the existing private-store communication fixture.
# Reuse its channel hooks; replace physiology/evaluation with current source.
using JSON3
length(ARGS) in (2,3,4,5) || error("usage: trade_run.jl COMMUNICATION_BASE NEW_OUTPUT [DAYS] [DAILY_QUANTITY] [ACTOR_SUPPLY_JSON]")
const macro_trade_days=length(ARGS)>=3 ? parse(Int,ARGS[3]) : 5
const macro_trade_quantity=length(ARGS)>=4 ? parse(Int,ARGS[4]) : nothing
const macro_trade_actor_supply=length(ARGS)==5 ? JSON3.read(read(ARGS[5],String),Dict{String,Any}) : Dict{String,Any}()
all(v->v isa Integer && !(v isa Bool) && v>=0,values(macro_trade_actor_supply)) || error("actor supply must be nonnegative integer quantities")
macro_trade_quantity===nothing || macro_trade_quantity>0 || error("positive daily quantity required")
macro_trade_days>=3 || error("fixed tasting requires at least 3 days")
const macro_trade_base=abspath(ARGS[1]);const macro_trade_output=abspath(ARGS[2])
const macro_trade_repo=normpath(joinpath(@__DIR__,"../.."))
const macro_trade_prepared=macro_trade_output*"-prepared"
ispath(macro_trade_prepared) && error("fresh prepared directory required")
mkpath(macro_trade_prepared)
cp(joinpath(macro_trade_base,"source"),joinpath(macro_trade_prepared,"source"))
cp(joinpath(macro_trade_repo,"src"),joinpath(macro_trade_prepared,"source/src");force=true)
const macro_trade_input=JSON3.read(read(joinpath(macro_trade_base,"input.json"),String),Dict{String,Any})
macro_trade_input["scene"]["macronutrient_body"]=true
macro_trade_input["scene"]["open_stores"]=false
if macro_trade_quantity!==nothing
    for supply in values(macro_trade_input["scene"]["personal_food_supply"])
        supply["quantity"]=macro_trade_quantity
    end
end
for (actor,quantity) in macro_trade_actor_supply
    haskey(macro_trade_input["scene"]["personal_food_supply"],actor) || error("unknown supply actor: "*actor)
    macro_trade_input["scene"]["personal_food_supply"][actor]["quantity"]=quantity
end
write(joinpath(macro_trade_prepared,"input.json"),JSON3.write(macro_trade_input))
write(joinpath(macro_trade_prepared,"source/src/data/lw_actor_ids.jl"),"const IDS="*repr(Tuple(macro_trade_input["scene"]["experimental_actor_ids"]))*"\n")
function replace_once(text,old,new)
    length(findall(old,text))==1 || error("communication integration marker: "*old)
    replace(text,old=>new)
end
macro_trade_day=read(joinpath(macro_trade_base,"source/src/lw/simulation/day.jl"),String)
macro_trade_day=replace(macro_trade_day,"\r\n"=>"\n")
macro_trade_day=replace_once(macro_trade_day,
    "Digestion(;taste_preference=preference)\n        end for a in IDS)",
    "Digestion(;taste_preference=preference,macronutrients=get(spec,:macronutrient_body,true),reserve=spec.reserve[actor_index],day_seconds=clock.day_us/1e6)\n        end for (actor_index,a) in enumerate(IDS))")
macro_trade_day=replace_once(macro_trade_day,
    "hunger_update!(hunger[a],a,now,w.bodies[a].reserve;continuous=get(spec,:hunger_forecast,true))",
    "physical_body_demand=guts!==nothing && guts[a].macro_body!==nothing ? RDLBody.Macronutrients.body_signals(guts[a].macro_body.body,RDLBody.MACRO_PARAMETERS).body_demand : nothing\n                hunger_update!(hunger[a],a,now,w.bodies[a].reserve;continuous=get(spec,:hunger_forecast,true),body_demand=physical_body_demand)")
macro_trade_day=replace_once(macro_trade_day,"advance_physiology!(w,metabolism,guts,food_body)","advance_physiology!(w,metabolism,guts,food_body;plans,sleeping_ids)")
macro_trade_day=replace_once(macro_trade_day,"daily[end][\"home_activity\"]=home_activity_snapshot(storage_stats[\"home_activity\"])",
    "daily[end][\"home_activity\"]=home_activity_snapshot(storage_stats[\"home_activity\"])\n            guts!==nothing && (daily[end][\"digestion\"]=D(a=>digestion_snapshot(guts[a]) for a in IDS))")
macro_trade_day=replace_once(macro_trade_day,"w.bodies[a]=Body(10.,0.,spec.reserve[i],0.)",
    "w.bodies[a]=HumanBody(guts[a].macro_body.body,guts[a].macro_body.hours_per_second)")
macro_trade_day=replace(macro_trade_day,r"\b(w\.bodies\[a\]|repetition_before|premeal)\.reserve"=>s->"body_energy("*s[1:end-8]*")")
macro_trade_day=replace(macro_trade_day,"delta[\"reserve\"]"=>"body_energy_delta(delta)",
    "body_energy(w.bodies[a])<80"=>"body_demand(w.bodies[a])>0",
    "body_energy(w.bodies[a])>0"=>"body_alive(w.bodies[a])",
    "body_energy(w.bodies[a])<=0"=>"!body_alive(w.bodies[a])")
write(joinpath(macro_trade_prepared,"source/src/lw/simulation/day.jl"),macro_trade_day)
const macro_trade_channels=joinpath(macro_trade_repo,"experiments/simple_language")
macro_trade_runner=read(joinpath(macro_trade_channels,"cohort_run.jl"),String)
macro_trade_runner=replace_once(macro_trade_runner,"const HERE=@__DIR__","const HERE="*repr(macro_trade_channels))
macro_trade_runner=replace_once(macro_trade_runner,"MODE==\"train\" ? 3 : STARTDAY","MODE==\"train\" ? $macro_trade_days : STARTDAY")
# The fixture already has five actors; do not append a duplicate E.
macro_trade_runner=replace_once(macro_trade_runner,"if MODE in (\"train\",\"join\")","if MODE==\"join\"")
ENV["RDL_LEARNED_TRADE"]="1";ENV["RDL_WANT_VOICE"]="1"
ENV["RDL_ALTERNATE_E"]="0";ENV["RDL_NO_GESTURES"]="0"
println("5 actors, fresh $macro_trade_days days: existing fixed tasting 3 days + interaction $(macro_trade_days-3) days; private warehouses; per-actor food supply; no API; macro body and public appearance.")
println("Daily supply: ",JSON3.write(macro_trade_input["scene"]["personal_food_supply"]))
flush(stdout)
empty!(ARGS);append!(ARGS,["train",macro_trade_prepared,macro_trade_output])
include_string(Main,macro_trade_runner,joinpath(macro_trade_channels,"macro_trade_generated.jl"))
