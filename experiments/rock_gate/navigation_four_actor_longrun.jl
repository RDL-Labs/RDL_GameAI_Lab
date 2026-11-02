using JSON3, SHA, Test, Serialization
length(ARGS)==2 || error("usage: navigation_four_actor_longrun.jl BASE_RUN NEW_OUTPUT")
base=abspath(ARGS[1]);out=abspath(ARGS[2]);ispath(out) && error("fresh output required")
input=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any})
s=input["scene"];c=input["config"];days=180
ids=["npc_a","npc_b","npc_c","npc_d"]
s["experimental_actor_ids"]=ids;c["days"]=days
h=s["home"]
# Opposite starting positions within each sensitivity group, equal radius.
s["positions"]=[[h[1]+dx,h[2]+dz] for (dx,dz) in ((.3,0.),(-.3,0.),(0.,.3),(0.,-.3))]
s["reserve"]=fill(70,4);s["initial_inventory"]=fill(1,4)
s["initial_inventory_kinds"]=[[3] for _ in ids]
s["initial_personal_stock"]=fill(60,4)
s["initial_personal_food_counts"]=Dict(a=>[60,0,0,0] for a in ids)
c["mb_sensitivities"]=Dict(a=>Dict(k=>(i<=2 ? .5 : 1.) for k in ("delay","stagnation","energy","contradiction")) for (i,a) in enumerate(ids))
capacity=4*days*cld(input["clock"]["day_us"],1_000_000)+1
for f in s["food"];f["stock"]=capacity;end
@testset "four actor conditions" begin
    @test length(s["positions"])==length(ids)==4
    @test all(hypot(p[1]-o["x"],p[2]-o["z"])>o["radius"] for p in s["positions"] for o in s["obstacles"] if get(o,"solid",true))
    @test all(s[k]===false for k in ("food_exchange","social_relationships","incidental_items"))
    @test !s["wildlife"]["enabled"]
    @test !haskey(s,"food_season")
end
mkpath(out);cp(joinpath(base,"source"),joinpath(out,"source"))
roster_file=joinpath(out,"source/src/data/lw_actor_ids.jl")
write(roster_file,"# Experimental frozen four-actor roster.\nconst IDS="*repr(Tuple(ids))*"\n")
write(joinpath(out,"input.json"),JSON3.write(input))
write(joinpath(out,"conditions.json"),JSON3.write((days=days,actors=ids,sensitivity=c["mb_sensitivities"],seed=c["seed"],
    base=base,initial_experience="none",initial_reserve=70,personal_food=60,held_raw_acorn=1,
    per_site_stock=capacity,wall_limit_hours=8,checkpoints="daily",initial_observation_days=1,
    comparison_note="Shared-world exploratory comparison, two actors per group; not independent replicated trials")))
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
@testset "loaded roster and input binding" begin
    @test collect(IDS)==ids
    for key in ("positions","reserve","initial_inventory","initial_inventory_kinds","initial_personal_stock")
        @test length(s[key])==length(IDS)
    end
    @test Set(keys(c["mb_sensitivities"]))==Set(IDS)
    w=moving_world(JSON3.read(JSON3.write(s)))
    @test Set(keys(w.positions))==Set(IDS)
    for (i,a) in enumerate(IDS)
        @test collect(w.positions[a])==s["positions"][i]
        @test length(s["initial_inventory_kinds"][i])==s["initial_inventory"][i]
        @test all(==(i<=2 ? .5 : 1.),values(c["mb_sensitivities"][a]))
    end
end
smoke=deepcopy(input);smoke["config"]["days"]=1
write(joinpath(out,"day-one-input.json"),JSON3.write(smoke))
println("VERIFY first day before continuing");flush(stdout)
native_main([joinpath(out,"day-one"),"--spec",joinpath(out,"day-one-input.json"),"--checkpoint-dir",joinpath(out,"checkpoints")])
first_checkpoint=joinpath(out,"checkpoints/day-001.jls")
verified_state=deserialize(first_checkpoint).state
@testset "four actors actually executed day one" begin
    @test Set(keys(verified_state[:mb_maps]))==Set(IDS)
    @test Set(keys(verified_state[:counts]))==Set(IDS)
    for (i,a) in enumerate(IDS)
        @test sum(values(verified_state[:counts][a]))==cld(input["clock"]["day_us"],1_000_000)
        @test verified_state[:mb_maps][a]["sensitivity"]==c["mb_sensitivities"][a]
    end
end
write(joinpath(out,"day-one-verified.json"),JSON3.write((actors=ids,roster_sha256=bytes2hex(sha256(read(roster_file))),verified=true)))
println("START 180 days / 4 actors / A,B=0.5 C,D=1.0 / fresh experience");flush(stdout)
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--resume-from",first_checkpoint,"--checkpoint-dir",joinpath(out,"checkpoints")])
r=JSON3.read(read(joinpath(out,"run/result.json"),String))
@testset "longrun isolation and accounting" begin
    @test length(r.daily)==days
    @test length(r.final_agents)==4
    @test all(>(0),r.world_checkpoint.stock[1:length(s["food"])])
    @test r.replenished_food==0
    @test all(!(e.action in ("request","give","trade_offer","item_offer","item_pickup")) for e in r.events)
    for d in r.daily
        @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
    end
end
write(joinpath(out,"completed.json"),JSON3.write((days=days,actors=4)))
