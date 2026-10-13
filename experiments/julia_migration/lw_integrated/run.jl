include(joinpath(@__DIR__,"../lw_day/run.jl"))
@testset "finite safety selection" begin
    m=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
    seen=D("coverage"=>"complete","features"=>[D("forward"=>2.,"right"=>2.,"distance"=>sqrt(8.))])
    clear=D("coverage"=>"complete","features"=>Any[])
    s=safety_state()
    @test safety_plan!(s,clear,m)===nothing
    @test safety_plan!(s,seen,m)["action"]=="walk"
    @test s["active"] && s["entries"]==1
    blocked=D("energy"=>D("rows"=>[D("ref"=>"0","cost"=>nothing)]))
    @test safety_plan!(s,seen,blocked)["action"]=="scan"
    for i in 1:3
        @test safety_plan!(s,clear,m)["action"]=="scan"
    end
    @test safety_plan!(s,clear,m)===nothing
    @test s["releases"]==1 && !s["active"]
    @test safety_plan!(s,seen,m)!==nothing && s["entries"]==2
    safety_plan!(s,clear,m)
    safety_plan!(s,seen,m)
    @test s["H"]==0
    w=(positions=Dict("a"=>(0.,0.)),obstacles=Any[])
    yaw=Dict("a"=>0.)
    hs=[(x=0.,z=2.,vx=1.,vz=0.,start=0,stop=10)]
    ob=hazard_observation(w,"a",yaw,hs,1)
    @test length(ob["features"])==1
    @test ob["features"][1]["right"]==1.
    @test Set(keys(ob["features"][1]))==Set(["forward","right","distance"])
    @test isempty(hazard_observation(w,"a",yaw,hs,10)["features"])
    yaw["a"]=180.
    @test isempty(hazard_observation(w,"a",yaw,hs,1)["features"])
end
function run_integrated(input)
cfg=input.config
enabled=cfg.learning=="full"
@assert cfg.learning in ("off","full") && cfg.food in ("finite","renewable")
r=lw_day(input.scene,input.clock;days=Int(cfg.days),basic_loop=true,landmark_routes=true,
    harvest_sleep=enabled,model_field=enabled,model_review=enabled,model_relearn=enabled,
    renewable_food=cfg.food=="renewable",hazard_mode=cfg.hazards=="crossing")
@testset "LW-Julia integrated invariants" begin
    @test r["ended_us"]==cfg.days*input.clock.day_us
    @test all(sum(values(r["counts"][a]))==cfg.days*17_280 for a in IDS)
    @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
    @test all(isfinite(v) for s in values(r["final_agents"]) for v in values(s["body"]) if v isa Number)
end
summary=D("name"=>"LW-Julia integrated experiment v1","config"=>cfg,"ended_us"=>r["ended_us"],
    "food"=>D("initial"=>r["initial_food"],"added"=>r["replenished_food"],"ground"=>r["ground"],"consumed"=>r["consumed"]),
    "safety"=>r["safety"],"agents"=>D())
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
