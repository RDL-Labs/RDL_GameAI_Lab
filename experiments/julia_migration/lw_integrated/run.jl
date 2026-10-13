include(joinpath(@__DIR__,"../lw_day/run.jl"))
function run_integrated(input)
cfg=input.config
enabled=cfg.learning=="full"
@assert cfg.learning in ("off","full") && cfg.food in ("finite","renewable")
r=lw_day(input.scene,input.clock;days=Int(cfg.days),basic_loop=true,landmark_routes=true,
    harvest_sleep=enabled,model_field=enabled,model_review=enabled,model_relearn=enabled,
    renewable_food=cfg.food=="renewable",hazard_mode=cfg.hazards=="crossing",ground_mode=get(cfg,:ground,"flat"),running=get(cfg,:running,"off")=="on")
summary=D("name"=>"LW-Julia integrated experiment v1","config"=>cfg,"ended_us"=>r["ended_us"],
    "food"=>D("initial"=>r["initial_food"],"added"=>r["replenished_food"],"ground"=>r["ground"],"consumed"=>r["consumed"]),
    "running"=>r["running"],"ground_effects"=>r["ground_effects"],"safety"=>r["safety"],"agents"=>D())
for a in IDS
    s=r["final_agents"][a];h=s["harvest"]
    summary["agents"][a]=D("position"=>s["position"],"body"=>s["body"],"inventory"=>s["inventory"],
        "stock"=>s["personal_stock"],"distance"=>s["distance"],"operations"=>sum(values(r["counts"][a])),
        "night_statuses"=>[n["sleep"][a]["sleep"]["cycle"]["status"] for n in r["daily"]],
        "model_ref"=>h===nothing || h["model"]===nothing ? nothing : h["model"]["model_ref"],
        "replacement_used"=>h===nothing ? false : get(h,"replacement_used",false),"model_field"=>s["model_field"])
end
return r,summary
end

if abspath(PROGRAM_FILE)==@__FILE__
    r,summary=run_integrated(JSON3.read(read(ARGS[1],String)))
    open(ARGS[2],"w") do io;JSON3.write(io,r);end
    open(ARGS[3],"w") do io;JSON3.write(io,summary);end
end
