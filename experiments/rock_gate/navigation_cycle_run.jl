# Isolated exploration/harvest/return cycle; no scripted movement or success.
using JSON3, SHA, Test
length(ARGS)==1 || error("usage: navigation_cycle_run.jl NEW_OUTPUT")
const repo=normpath(joinpath(@__DIR__,"../.."))
const out=abspath(only(ARGS));ispath(out) && error("fresh output required")
const base=joinpath(repo,"experiments/portable_items/attention_10d_input.json")
input=JSON3.read(read(base,String),Dict{String,Any})
input["config"]["days"]=10
scene=input["scene"]
for key in ("incidental_items","food_exchange","social_relationships","item_attention","gradient_logging")
    scene[key]=false
end
scene["wildlife"]["enabled"]=false
scene["loose_items"]=Any[]
scene["name"]="strong-relations-navigation-cycle"
mkpath(out)
snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
# Explicit experiment-only configured path. Legacy aid initiation has no OFF flag.
day=joinpath(snapshot,"src/lw/simulation/day.jl")
source=read(day,String)
needle="elseif ((food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) || forecast_request_ready)"
length(findall(needle,source))==1 || error("aid ablation anchor changed")
write(day,replace(source,needle=>"elseif false && ((food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) || forecast_request_ready)"))
write(joinpath(out,"input.json"),JSON3.write(input))
cp(@__FILE__,joinpath(out,"runner.jl"))
write(joinpath(out,"conditions.json"),JSON3.write((days=10,actors=3,seed=input["config"]["seed"],
    base_sha256=bytes2hex(sha256(read(base))),configured_ablation="disable aid initiation in frozen source only",
    disabled=["trade","aid requests","incidental pickup","wildlife"],source_commit=strip(read(`git -C $repo rev-parse HEAD`,String)))))
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
println("START navigation cycle: 3 actors, 10 days, no trade/aid/pickup/wildlife");flush(stdout)
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--checkpoint-dir",joinpath(out,"checkpoints")])
r=JSON3.read(read(joinpath(out,"run/result.json"),String))
@testset "navigation cycle isolation and accounting" begin
    @test length(r.daily)==10
    @test length(r.final_agents)==3
    @test !haskey(r,:food_exchange)
    @test !haskey(r,:incidental_items)
    @test !haskey(r,:social_relationships)
    @test all(!(e.action in ("request","give","trade_offer","item_offer","item_pickup")) for e in r.events)
    for d in r.daily
        @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
    end
end
write(joinpath(out,"completed.json"),JSON3.write((days=10,kind="navigation-cycle")))
println("COMPLETED navigation cycle")
