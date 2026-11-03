using Test, JSON3
include("../../integrations/lightweight_julia/native.jl")
@testset "declared idle eligibility" begin
    s=D("daily_plan"=>D("active"=>D("closed"=>true,"deadline_us"=>100),"records"=>[D("returned"=>true,"food_success"=>true)]),
        "configured_post_return_idle"=>configured_post_return_idle_state())
    @test configured_post_return_idle!(s,10,100,70)
    @test !configured_post_return_idle!(s,11,100,70;pending=true)
    @test !configured_post_return_idle!(s,11,100,70;observing=true)
    @test configured_post_return_idle!(s,12,100,70)
    @test !configured_post_return_idle!(s,70,100,70)
    @test !configured_post_return_idle!(s,100,100,70)
    s["daily_plan"]["records"][1]["food_success"]=false
    @test !configured_post_return_idle!(s,13,100,70) # Even a legacy closed empty return cannot pause.
    s["daily_plan"]["records"][1]["food_success"]=true
    s["daily_plan"]["records"][1]["returned"]=false
    @test !configured_post_return_idle!(s,13,100,70)
end
@testset "idle integration, physiology, sleep, and checkpoint" begin
    input=JSON3.read(read(joinpath(@__DIR__,"navigation_edible_10d_input.json"),String),Dict{String,Any})
    c=input["config"];s=input["scene"]
    merge!(c,D("days"=>2,"home_observation"=>"off","night_fear"=>"off"))
    c["mb_sensitivities"]=D(a=>c["mb_sensitivities"][a] for a in IDS)
    s["experimental_actor_ids"]=collect(IDS)
    for key in ("positions","reserve","initial_inventory","initial_inventory_kinds","initial_personal_stock")
        s[key]=s[key][1:length(IDS)]
    end
    s["initial_personal_food_counts"]=D(a=>s["initial_personal_food_counts"][a] for a in IDS)
    s["post_return_idle"]=true
    s["configured_camp_landmark"]=false;s["configured_camp_experience"]=false
    s["positions"]=[copy(s["home"]) for _ in IDS]
    s["initial_inventory"]=fill(0,length(IDS));s["initial_inventory_kinds"]=[Int[] for _ in IDS]
    s["food"]=[D("x"=>0.,"z"=>6.5,"stock"=>100000,"food_kind"=>1)]
    s["obstacles"]=Any[];s["low_obstacles"]=Any[]
    println("CONDITIONS: 3 actors, 2 days, abundant finite nearby fruit, no processing/trade/aid; fixed post-return cognition pause ON until night; physiology and sleep ON.")
    r=mktempdir() do dir
        spec=JSON3.read(JSON3.write(input))
        full,_=run_integrated(spec;checkpoint_dir=dir)
        resumed,_=run_integrated(spec;resume_from=joinpath(dir,"day-001.jls"))
        @test full==resumed
        full
    end
    for a in IDS
        m=r["mb_map"][a];idle=m["configured_post_return_idle"]
        @test idle["ticks"]>0
        @test idle["entries"]>=2
        @test m["observations"]+idle["ticks"]==34560
        @test sum(values(r["counts"][a]))==34560
        @test r["food_body"]["metabolic_loss"][a]>0
        @test all(d["sleep"][a]["sleep"]["cycle"]["status"]=="completed" for d in r["daily"])
        @test length(m["sleep"]["reviews"])==2
        @test !idle["active"]
    end
    @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["shared_stock"]+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
    println("IDLE_TICKS ",JSON3.write(D(a=>r["mb_map"][a]["configured_post_return_idle"]["ticks"] for a in IDS)))
end
