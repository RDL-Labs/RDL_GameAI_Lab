using Test
include("../../../integrations/lightweight_julia/native.jl")
function daily_fixture()
    s=mb_map_state("test");s["daily_plan"]=mb_daily_plan_state("test",9)
    mb_plan_context!(s,0,600_000_000,70.,0.)
    s
end
@testset "daily plan keeps a deadline across uncertain stages" begin
    s=daily_fixture();move=D("visible"=>Any[])
    mb_daily_request!(s,move,nothing,false,0,70.,0.,0,600_000_000)
    st=s["daily_plan"];a=st["active"]
    @test a["initial_mode"]=="unknown_food"
    @test a["evidence"]["source"]=="no_usable_memory"
    frozen=deepcopy(a["forecast"])
    for i in 0:9;mb_daily_result!(s,D("action"=>"walk"),"performed",i*1_000_000,.1,0);end
    visible=D("visible"=>[D("distance"=>5.)])
    mb_daily_request!(s,visible,nothing,false,0,69.,0.,10_000_000,600_000_000)
    @test a["evidence"]["mode"]=="known_food"
    @test a["deadline_us"]==600_000_000
    @test a["started_us"]==0
    @test a["forecast"]==frozen
    @test a["operations"]==10
    @test a["energy"]≈1.
    @test a["remaining_estimate"]["available_seconds"]==590.
    mb_daily_result!(s,D("action"=>"pickup"),"picked_up",11_000_000,.1,0)
    mb_daily_result!(s,D("action"=>"deposit"),"performed",30_000_000,.1,1;delivered_sources=["op:11000000:test"])
    record=only(st["records"])
    @test record["food_success"] && record["returned"] && record["on_time"]
    @test record["ended_us"]==31_000_000
    @test record["acquired"]==record["delivered"]==1
    @test only(st["models"]["roundtrip:unknown_food"])["seconds"]==31.
end
@testset "empty return and overdue continuation retain distinct outcomes" begin
    s=daily_fixture();move=D("visible"=>Any[])
    mb_daily_request!(s,move,nothing,false,0,70.,0.,0,600_000_000)
    a=s["daily_plan"]["active"];a["choice"]="home"
    mb_daily_stage!(s["daily_plan"],"return",20_000_000)
    a["operations"]=40;a["energy"]=.5
    forecast=deepcopy(a["forecast"])
    mb_daily_request!(s,move,D("distance"=>0.),true,0,70.,0.,40_000_000,600_000_000)
    record=only(s["daily_plan"]["local_returns"])
    @test record["returned"] && !record["food_success"]
    @test record["reason"]=="empty_return"
    @test !a["closed"] && isempty(s["daily_plan"]["records"])
    @test !haskey(s["daily_plan"]["models"],"roundtrip:unknown_food")
    @test only(filter(x->x["completed"],s["daily_plan"]["models"]["return"]))["seconds"]==20.
    @test a["forecast"]==forecast && a["started_us"]==0 && a["energy"]==.5 && a["operations"]==40
    mb_daily_request!(s,move,D("distance"=>0.),true,0,70.,0.,41_000_000,600_000_000)
    @test length(s["daily_plan"]["local_returns"])==1
    mb_daily_request!(s,move,nothing,false,0,70.,0.,600_000_000,600_000_000)
    a=s["daily_plan"]["active"]
    @test a["deadline_us"]==1_200_000_000
    mb_daily_request!(s,move,nothing,false,0,70.,0.,1_300_000_000,600_000_000)
    @test a["deadline_us"]==1_800_000_000 # expired strategy is recorded, not silently kept forever
    mb_plan_context!(s,1_300_000_000,600_000_000,70.,1.)
    b=mb_plan_budget(s,D("expected_actions"=>20.,"expected_energy"=>.1),"home")
    @test b["deadline_us"]==1_800_000_000
end
@testset "known and unknown estimates learn separately" begin
    st=mb_daily_plan_state("test",1)
    mb_daily_learn!(st,"known_food",12.,.2,true,"acquired")
    mb_daily_learn!(st,"unknown_food",50.,1.,true,"located")
    mb_daily_learn!(st,"unknown_food",1000.,9.,false,"empty_return")
    @test mb_daily_estimate(st,"known_food",128.)["seconds"]==12.
    @test mb_daily_estimate(st,"unknown_food",128.)["seconds"]==50.
    @test !last(st["models"]["unknown_food"])["completed"]
    s=daily_fixture()
    mb_daily_learn!(s["daily_plan"],"plan:explore",900.,3.,true,"delivered")
    mb_daily_request!(s,D("visible"=>Any[]),nothing,false,0,70.,0.,0,600_000_000)
    @test s["daily_plan"]["active"]["forecast"]["seconds"]==900.
    mb_daily_learn!(s["daily_plan"],"plan:explore",100.,1.,true,"delivered")
    mb_daily_request!(s,D("visible"=>Any[]),nothing,false,0,70.,0.,64_000_000,600_000_000)
    @test s["daily_plan"]["active"]["forecast"]["seconds"]==900.
end
@testset "a new daily plan does not inherit an expired unfinished child" begin
    s=daily_fixture();move=D("visible"=>Any[])
    mb_daily_request!(s,move,nothing,false,0,70.,0.,0,600_000_000)
    p=D("action"=>"scan","priority"=>1.)
    mb_parent_begin!(s,p,"food",nothing,0);mb_parent_record!(s,p,.1,0)
    old=s["parent_mb"]["active"]["food"]
    s["daily_plan"]["active"]["choice"]="home"
    mb_daily_result!(s,D("action"=>"pickup"),"picked_up",30_000_000,0.,0;acquired_source="new-food")
    mb_daily_result!(s,D("action"=>"deposit"),"performed",39_000_000,0.,1;delivered_sources=["new-food"])
    mb_daily_request!(s,move,D("distance"=>0.),true,0,70.,0.,40_000_000,600_000_000)
    mb_plan_context!(s,600_000_000,600_000_000,70.,1.)
    mb_daily_request!(s,move,nothing,false,0,70.,0.,600_000_000,600_000_000)
    p=D("action"=>"scan","priority"=>1.)
    mb_parent_candidates!(s,[p],"food",nothing)
    @test p["mb_parent_estimate"]["planning"]["deadline_us"]==1_200_000_000
    mb_parent_begin!(s,p,"food",nothing,600_000_000)
    @test s["parent_mb"]["active"]["food"]!==old
    @test s["parent_mb"]["active"]["food"]["actions"]==0
    @test only(s["parent_mb"]["models"]["food:search"]["observations"])["reason"]=="daily_plan_ended"
end
@testset "tentative food knowledge and initial cargo are not false successes" begin
    s=daily_fixture();arrival=goal_arrival_state();s["goal_arrival"]=D("food"=>arrival)
    goal_arrival_update!(arrival,D("forward"=>5.,"right"=>0.),"food",.9,0)
    move=D("visible"=>Any[])
    @test mb_daily_evidence(s,move,70.,0.,0)["source"]=="provisional_location"
    arrival["mode"]="search"
    @test mb_daily_evidence(s,move,70.,0.,0)["mode"]=="unknown_food"
    mb_daily_request!(s,move,D("distance"=>0.),true,1,70.,0.,0,600_000_000)
    mb_daily_result!(s,D("action"=>"deposit"),"performed",0,0.,1)
    @test !s["daily_plan"]["active"]["closed"]
    @test isempty(s["daily_plan"]["records"])
    mb_daily_result!(s,D("action"=>"pickup"),"picked_up",1_000_000,0.,0;acquired_source="new-food")
    mb_daily_result!(s,D("action"=>"recover"),"recovered",2_000_000,0.,0;acquired_source="new-food")
    @test s["daily_plan"]["active"]["acquired"]==1
    s["daily_plan"]["active"]["departed"]=true
    mb_daily_result!(s,D("action"=>"deposit"),"performed",3_000_000,0.,1;delivered_sources=["old-food"])
    @test !only(s["daily_plan"]["local_returns"])["food_success"]
    @test !s["daily_plan"]["active"]["closed"] && isempty(s["daily_plan"]["records"])
    mb_daily_result!(s,D("action"=>"deposit"),"performed",4_000_000,0.,1;delivered_sources=["new-food"])
    @test only(s["daily_plan"]["records"])["food_success"]
    @test s["daily_plan"]["active"]["closed"]
end
@testset "confirmed approach completes its suspended full journey" begin
    for succeeded in (false,true)
        s=daily_fixture();loop=BasicLoop("home";probabilistic=true)
        arrival=goal_arrival_state();s["goal_arrival"]=D("home"=>arrival)
        p=D("action"=>"scan");mb_parent_begin!(s,p,"home",nothing,0)
        mb_parent_record!(s,p,.1,0)
        original=s["parent_mb"]["active"]["home"]
        mb_parent_learn!(s,"home",original,false,"unfinished")
        goal_arrival_update!(arrival,D("forward"=>2.,"right"=>0.),"home",1.,1_000_000)
        mb_parent_arrival_sync!(s,loop,"home",1_000_000)
        local_plan=D("action"=>"walk")
        mb_parent_begin!(s,local_plan,"home",D("distance"=>2.),1_000_000)
        mb_parent_record!(s,local_plan,.2,1_000_000)
        if succeeded
            mb_parent_H_increment!(s,"home","op:1000000:test",true,2_000_000)
            goal_arrival_update!(arrival,nothing,nothing,0.,2_000_000;completed=true)
        else
            arrival["mode"]="search"
        end
        mb_parent_arrival_sync!(s,loop,"home",2_000_000)
        @test original["actions"]==2 && original["energy"]≈.3
        model=s["parent_mb"]["models"]["home:search"]
        @test only(model["observations"])["completed"]==succeeded
        if succeeded
            @test only(model["observations"])["actions"]==2
            @test model["samples"]==1
            mb_parent_arrival_sync!(s,loop,"home",3_000_000)
            @test model["samples"]==1
        else
            @test s["parent_mb"]["active"]["home"]===original
            @test original["estimate"]["planning"]["deadline_us"]==600_000_000
        end
    end
end
@testset "remembered food route is usable evidence, not hidden world knowledge" begin
    s=mb_map_state("test";chunks=true)
    view(t,band)=D("source"=>"ob:$t:test","coverage"=>"complete","features"=>[
        D("color"=>"brown","azimuth"=>[-5.,5.],"range_band"=>band,"distance"=>5.),
        D("color"=>"gray","azimuth"=>[40.,50.],"range_band"=>"far","distance"=>20.)])
    p=D("action"=>"walk","direction"=>0,"purpose_family"=>"food")
    mb_observe!(s,view(0,"far"),0);mb_record!(s,p,"performed",.01,0)
    mb_observe!(s,view(1_000_000,"mid"),1_000_000);mb_record!(s,p,"performed",.01,1_000_000)
    mb_observe!(s,view(2_000_000,"near"),2_000_000;food=true)
    @test mb_goal_result!(s,"food","op:1000000:test",true,8,0,2_000_000)
    mb_observe!(s,view(3_000_000,"far"),3_000_000)
    move=D("visible"=>Any[],"energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
    evidence=mb_daily_evidence(s,move,70.,0.,3_000_000)
    @test evidence["source"]=="remembered_route" && evidence["mode"]=="known_food"
    empty!(s["edges"])
    @test mb_daily_evidence(s,move,70.,0.,3_000_000)["mode"]=="unknown_food"
end
@testset "daily objective connected to world accounting" begin
    input=JSON3.read(read(joinpath(@__DIR__,"search_review_spec.json"),String),Dict{String,Any})
    merge!(input["config"],D("days"=>2,"body_purpose"=>"on","mb_simulation"=>"on",
        "general_landmarks"=>"on","rho_profile"=>"coarse","daily_delivery"=>"on"))
    input["clock"]["day_us"]=600_000_000
    input["clock"]["phase_boundaries_us"]=[1_000_000,2_000_000,3_000_000,600_000_000]
    input["clock"]["quiet_night_us"]=4_000_000
    r=mktempdir() do dir
        spec=JSON3.read(JSON3.write(input))
        full,_=run_integrated(spec;checkpoint_dir=dir)
        resumed,_=run_integrated(spec;resume_from=joinpath(dir,"day-001.jls"))
        @test full==resumed
        full
    end
    @test all(m["daily_plan"]["active"]!==nothing for m in values(r["mb_map"]))
    @test all(!isempty(m["daily_plan"]["decisions"]) for m in values(r["mb_map"]))
    @test all(sum(values(c))==1200 for c in values(r["counts"]))
    @test !isempty(JSON3.write(r))
    @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["shared_stock"]+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
end
