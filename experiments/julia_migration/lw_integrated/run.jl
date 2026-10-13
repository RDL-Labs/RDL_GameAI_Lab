include(joinpath(@__DIR__,"../lw_day/run.jl"))
input=JSON3.read(read(ARGS[1],String));cfg=input.config
enabled=cfg.learning=="full"
@assert cfg.learning in ("off","full") && cfg.food in ("finite","renewable")
r=lw_day(input.scene,input.clock;days=Int(cfg.days),basic_loop=true,landmark_routes=true,
    harvest_sleep=enabled,model_field=enabled,model_review=enabled,model_relearn=enabled,
    renewable_food=cfg.food=="renewable")
@testset "LW-Julia integrated invariants" begin
    @test r["ended_us"]==cfg.days*input.clock.day_us
    @test all(sum(values(r["counts"][a]))==cfg.days*17_280 for a in IDS)
    @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
    @test all(isfinite(v) for s in values(r["final_agents"]) for v in values(s["body"]) if v isa Number)
end
summary=D("name"=>"LW-Julia integrated experiment v1","config"=>cfg,"ended_us"=>r["ended_us"],
    "food"=>D("initial"=>r["initial_food"],"added"=>r["replenished_food"],"ground"=>r["ground"],"consumed"=>r["consumed"]),
    "agents"=>D())
for a in IDS
    s=r["final_agents"][a];h=s["harvest"]
    summary["agents"][a]=D("position"=>s["position"],"body"=>s["body"],"inventory"=>s["inventory"],
        "stock"=>s["personal_stock"],"distance"=>s["distance"],"operations"=>sum(values(r["counts"][a])),
        "night_statuses"=>[n["sleep"][a]["sleep"]["cycle"]["status"] for n in r["daily"]],
        "model_ref"=>h===nothing || h["model"]===nothing ? nothing : h["model"]["model_ref"],
        "replacement_used"=>h===nothing ? false : get(h,"replacement_used",false),"model_field"=>s["model_field"])
end
open(ARGS[2],"w") do io;JSON3.write(io,r);end
open(ARGS[3],"w") do io;JSON3.write(io,summary);end
