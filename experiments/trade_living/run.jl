# Frozen-source finite-stock living experiment; trades are never forced.
using JSON3, Test, SHA
length(ARGS)==2 || error("usage: run.jl INPUT.json NEW_OUTPUT")
const original=abspath(ARGS[1]);const out=abspath(ARGS[2])
const repo=normpath(joinpath(@__DIR__,"../.."))
ispath(out) && error("fresh output required")
const input=JSON3.read(read(original,String))
@assert input.scene.configured_trade_living
@assert isempty(input.scene.food) && input.config.food=="finite"
@assert !input.scene.wildlife.enabled
@assert !input.scene.configured_fishing_training
@assert !input.scene.configured_salted_fish_sample
@assert !input.scene.post_return_idle
isempty(get(input.scene,:configured_item_actions,Any[])) || error("placement run requires no scripted item actions")
const placed=get(input.scene,:loose_items,get(input.scene,:portable_items,Any[]))
isempty(placed) && error("place loose items first")
const incidental=get(input.scene,:incidental_items,false)
println("FINITE TRADE LIVING: $(input.config.days) days; no food sites, regrowth or forced trades")
mkpath(out);const snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
const roster=String.(get(input.scene,:experimental_actor_ids,["npc_a","npc_b","npc_c"]))
if haskey(input.scene,:experimental_actor_ids)
    3<=length(roster)<=30 && length(unique(roster))==length(roster) || error("experimental roster")
    roster[1:3]==["npc_a","npc_b","npc_c"] || error("retain legacy actor labels")
    all(occursin(r"^npc_[a-z0-9_]+$",a) for a in roster) || error("actor label")
    for key in (:positions,:reserve,:initial_inventory,:initial_inventory_kinds,:initial_personal_stock)
        length(getproperty(input.scene,key))==length(roster) || error("roster input length: $key")
    end
    # Isolated experiment, following the six-actor transfer runner. Default
    # production roster and other running snapshots are never modified.
    write(joinpath(snapshot,"src/data/lw_actor_ids.jl"),"# Experimental frozen roster.\nconst IDS="*repr(Tuple(roster))*"\n")
end
cp(@__FILE__,joinpath(out,"runner.jl"));cp(original,joinpath(out,"input.json"))
write(joinpath(out,"origin.json"),JSON3.write((path=original,sha256=bytes2hex(sha256(read(original))),
    actor_ids=roster,roster_sha256=bytes2hex(sha256(read(joinpath(snapshot,"src/data/lw_actor_ids.jl")))))))
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--checkpoint-dir",joinpath(out,"checkpoints")])
r=JSON3.read(read(joinpath(out,"run/result.json"),String))
@test length(r.daily)==input.config.days
@test Set(keys(r.final_agents))==Set(Symbol.(roster))
@test all(d->d.replenished_food==0,r.daily)
write(joinpath(out,"completed.json"),JSON3.write((kind="finite-trade-living",days=input.config.days,actors=roster)))
println("COMPLETED finite trade living")
