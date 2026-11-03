using Test, JSON3
include("../../integrations/lightweight_julia/native.jl")
@testset "empty food observations respect knowledge, view and occlusion" begin
    input=JSON3.read(read(joinpath(@__DIR__,"../julia_migration/lw_integrated/search_review_spec.json"),String))
    w=moving_world(input.scene);a=first(IDS);w.positions[a]=(0.,0.);yaw=Dict(x=>0. for x in IDS)
    food=[(x=0.,z=1.,stock=0)]
    observe_empty(;known=(),obstacles=Any[])=movement_observation(w,a,yaw,food,[0];known_food_sites=known,visual_obstacles=obstacles)
    @test isempty(observe_empty()["empty_food_sites"])
    @test observe_empty(known=(0,))["empty_food_sites"]==[0]
    yaw[a]=180.;@test isempty(observe_empty(known=(0,))["empty_food_sites"])
    yaw[a]=0.;@test isempty(observe_empty(known=(0,),obstacles=[RDLMigrationProbe.Circle(0.,.5,.2)])["empty_food_sites"])
    w.positions[a]=(0.,-10.);@test isempty(observe_empty(known=(0,))["empty_food_sites"])
end
@testset "finite site depletion reaches strategy selection in LW" begin
    input=JSON3.read(read(joinpath(@__DIR__,"navigation_idle_10d_input.json"),String),Dict{String,Any})
    s=input["scene"];c=input["config"]
    merge!(c,D("days"=>1,"home_observation"=>"off","night_fear"=>"off"))
    c["mb_sensitivities"]=D(a=>c["mb_sensitivities"][a] for a in IDS)
    s["experimental_actor_ids"]=collect(IDS)
    for k in ("positions","reserve","initial_inventory","initial_inventory_kinds","initial_personal_stock")
        s[k]=s[k][1:length(IDS)]
    end
    s["initial_personal_food_counts"]=D(a=>s["initial_personal_food_counts"][a] for a in IDS)
    s["configured_camp_landmark"]=false;s["configured_camp_experience"]=false
    s["positions"]=[copy(s["home"]) for _ in IDS];s["reserve"]=fill(90.,length(IDS))
    s["initial_inventory"]=fill(0,length(IDS));s["initial_inventory_kinds"]=[Int[] for _ in IDS]
    s["food"]=[D("x"=>0.,"z"=>6.5,"stock"=>1,"food_kind"=>1)]
    s["obstacles"]=Any[];s["low_obstacles"]=Any[]
    merge!(input["clock"],D("day_us"=>1200_000_000,"phase_boundaries_us"=>[1_000_000,900_000_000,1000_000_000,1200_000_000],"quiet_night_us"=>1100_000_000))
    println("CONDITIONS: 3 actors, 1200 ticks, one finite fruit, no regeneration, reserve 90, stock 60, initial observation OFF, provision-success idle ON.")
    r,_=run_integrated(JSON3.read(JSON3.write(input)))
    @test r["ground"]==0 && r["replenished_food"]==0
    switches=[x for m in values(r["mb_map"]) for x in m["daily_plan"]["plan_records"] if x["reason"] in ("observed_empty_site","food_not_found")]
    @test !isempty(switches)
    @test all(!x["completed"] for x in switches)
    @test all(sum(values(v))==1200 for v in values(r["counts"]))
    @test r["initial_food"]==r["ground"]+r["shared_stock"]+r["consumed"]+sum(f["inventory"]+f["personal_stock"] for f in values(r["final_agents"]))
    println("DEPLETION_SWITCHES ",JSON3.write(switches))
end
@testset "parent strategy switches without erasing upper goal or return knowledge" begin
    s=mb_map_state("test");s["daily_plan"]=mb_daily_plan_state("test",9)
    mb_plan_context!(s,0,600_000_000,80.,0.)
    visible=D("visible"=>[D("ref"=>0,"distance"=>1.)])
    missing=D("visible"=>Any[])
    mb_daily_request!(s,visible,nothing,false,0,80.,0.,0,600_000_000)
    st=s["daily_plan"];a=st["active"]
    @test a["strategy"]=="acquire"
    mb_daily_learn!(st,"plan:explore",800.,1.,true,"food_observed")
    mb_daily_learn!(st,"return",25.,.1,true,"arrived")
    p=D("action"=>"scan");mb_parent_begin!(s,p,"food",nothing,0);mb_parent_record!(s,p,.1,0)
    old=s["parent_mb"]["active"]["food"]
    mb_daily_result!(s,p,"performed",0,.1,0)
    mb_daily_request!(s,missing,nothing,false,0,80.,0.,1_000_000,600_000_000)
    @test a["strategy"]=="acquire" # Losing sight alone is not depletion.
    empty=D("visible"=>Any[],"empty_food_sites"=>[0])
    mb_daily_request!(s,empty,nothing,false,0,80.,0.,2_000_000,600_000_000)
    @test a["strategy"]=="explore" && a["plan_started_us"]==2_000_000
    @test a["started_us"]==0 && a["operations"]==1 && a["energy"]≈.1
    @test a["deadline_us"]==600_000_000 && !a["closed"] && isempty(st["records"])
    @test a["forecast"]["seconds"]==800.
    @test only(st["plan_records"])["reason"]=="observed_empty_site"
    @test !only(st["plan_records"])["completed"]
    mb_parent_candidates!(s,[D("action"=>"scan","priority"=>1.)],"food",nothing)
    @test !haskey(s["parent_mb"]["active"],"food")
    @test only(st["models"]["return"])["completed"]
    epoch=a["plan_epoch"]
    mb_daily_request!(s,empty,nothing,false,0,80.,0.,3_000_000,600_000_000)
    @test a["plan_epoch"]==epoch
    mb_daily_request!(s,missing,nothing,false,0,80.,0.,600_000_000,600_000_000)
    @test a["deadline_us"]==1_200_000_000 && a["started_us"]==0
    @test a["goal_deadline_us"]==600_000_000
    @test last(st["plan_records"])["reason"]=="deadline_unmet"
    @test !last(st["plan_records"])["completed"]
    mb_plan_context!(s,600_000_000,600_000_000,80.,.2)
    @test mb_plan_budget(s,D("expected_actions"=>10.,"expected_energy"=>.1),"food")["available_seconds"]==600.
    mb_daily_request!(s,visible,nothing,false,0,80.,0.,601_000_000,600_000_000)
    @test a["strategy"]=="acquire" && !(0 in st["empty_sites"])
    @test last(st["plan_records"])["completed"] # Discovery, not provision completion.
    @test !a["closed"] && isempty(st["records"])
    mb_daily_result!(s,D("action"=>"pickup","food_ref"=>0),"not_found",602_000_000,.1,0)
    @test a["strategy"]=="explore"
    @test last(st["plan_records"])["reason"]=="food_not_found"
    mb_daily_request!(s,visible,nothing,false,0,80.,0.,604_000_000,600_000_000)
    mb_daily_result!(s,D("action"=>"pickup","food_ref"=>0),"picked_up",605_000_000,.1,0;acquired_source="new-food")
    mb_daily_result!(s,D("action"=>"deposit"),"performed",606_000_000,.1,1;delivered_sources=["new-food"])
    @test only(st["records"])["food_success"]
    @test !only(st["records"])["on_time"]
    @test only(st["records"])["plan_on_time"]
end
