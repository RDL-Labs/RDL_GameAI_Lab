using Test
include("../../src/lw/LW.jl")
@testset "observed resources and owner-local aid prediction" begin
 relation=LW.social_relations_state("npc_a";relational=true)
 contacts=[LW.D("ref"=>"npc_b","holding_food"=>false)]
 stock=zeros(Int,length(LW.RDLBody.FOOD_KIND_IDS));stock[1]=4
 LW.aid_resource_observe!(relation,contacts,LW.D("npc_b"=>stock),LW.D())
 context=LW.social_aid_context(relation,"npc_b",LW.D("need"=>1.))
 @test LW.social_mb_context(context)==context
 plentiful=LW.aid_resource_prediction(context)
 @test plentiful["factor"]>0
 @test LW.aid_resource_prediction(merge(context,LW.D("distress"=>1.)))["factor"]<plentiful["factor"]
 @test LW.aid_resource_prediction(merge(context,LW.D("stock_faded"=>log1p(4))))["factor"]<plentiful["factor"]
 @test LW.aid_resource_prediction(merge(context,LW.D("holding_food"=>1.)))["factor"]>plentiful["factor"]
 pressure=LW.social_aid_pressure(LW.social_aid_state("npc_a"))
 _,trace=LW.select_target(["npc_b"],LW.D(),pressure;relation,seed="resource-test")
 @test trace["candidates"][1]["context"]["stock_kind_1"]==log1p(4)
 LW.aid_resource_observe!(relation,contacts,LW.D("npc_b"=>zeros(Int,length(stock))),LW.D())
 target,trace=LW.select_target(["npc_b"],LW.D(),pressure;relation,seed="resource-test")
 @test target===nothing
 @test length(trace["candidates"])==1
 LW.aid_resource_observe!(relation,contacts,LW.D(),LW.D())
 @test LW.aid_resource_prediction(LW.social_aid_context(relation,"npc_b"))["factor"]>0
 @test !haskey(LW.social_observed_context(relation,"npc_b"),"stock_edible")
 @test LW.aid_response_food(Int[],stock,true)==1
 @test LW.aid_response_food(Int[],stock,false)==0
 @test LW.aid_response_food([LW.RDLBody.SPOILED_FOOD],stock,true)==0
 pending=LW.D("target"=>"npc_b","food_kind"=>1,"deadline_us"=>5_000_000,"reply_to"=>"request-id")
 relation["aid_delivery"]=copy(pending)
 @test LW.aid_response_continue!(relation,[1],contacts,1_000_000)["action"]=="give"
 @test LW.aid_response_continue!(relation,[1],contacts,2_000_000)===nothing
 relation["aid_delivery"]=copy(pending)
 @test LW.aid_response_continue!(relation,Int[],contacts,1_000_000)["action"]=="refuse"
 relation["aid_delivery"]=copy(pending)
 @test LW.aid_response_continue!(relation,[1],contacts,5_000_000)===nothing
 relation["aid_delivery"]=copy(pending)
 @test LW.aid_response_continue!(relation,[1],Any[],1_000_000)===nothing
end
@testset "resource context learns refusal without leaking into other channels" begin
 relation=LW.social_relations_state("npc_a";relational=true)
 context=LW.D("need"=>1.,"holding_food"=>0.,"stock_known"=>1.,"stock_edible"=>log1p(4),"stock_kind_1"=>log1p(4))
 before=LW.social_mb_predict(relation,"npc_b","aid_received";situation=context)
 LW.social_relation_event!(relation,"npc_b","aid_received","refusal",1;outcome="refuse",context)
 after=LW.social_mb_predict(relation,"npc_b","aid_received";situation=context)
 @test after["probability"]<before["probability"]
 @test any(n["context"]==context for n in values(relation["mb"]["pending"]))
end
@testset "LW aid with empty hands and observed camp stores" begin
 scene=merge(LW.native_scene(19),(name="aid-resource-integration",positions=[[0.,0.],[0.,.75],[100.,100.]],
    home=[0.,0.],food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
    initial_inventory=[0,0,0],initial_inventory_kinds=[Int[],Int[],Int[]],
    initial_personal_stock=[0,10,0],initial_personal_food_counts=(npc_a=zeros(Int,8),npc_b=[10,0,0,0,0,0,0,0],npc_c=zeros(Int,8)),
    reserve=[30.,90.,100.],typed_food=true,social_relationships=true,open_stores=true))
 clock=merge(LW.native_clock(),(day_us=60_000_000,phase_boundaries_us=[60,60,60,60].*1_000_000,quiet_night_us=60_000_000))
 r=LW.lw_day(scene,clock;days=1,basic_loop=true,food_body=true,social_response=true,choice_seed=3)
 @test get(r["counts"]["npc_b"],"retrieve",0)>0
 @test get(r["counts"]["npc_b"],"give",0)>0
 @test any(record["outcome"]=="given" for record in r["final_agents"]["npc_a"]["aid"]["records"])
 @test r["initial_food"]==r["ground"]+r["consumed"]+sum(a["inventory"]+a["personal_stock"] for a in values(r["final_agents"]))
 @test any(haskey(record["forecast"]["context"],"stock_edible") for record in r["final_agents"]["npc_a"]["aid"]["records"])
 delayed=[record for record in r["social_relationships"]["npc_b"]["gradient_maps"]["records"] if
    record["channel"]=="aid_response" && any(o->o["status"]=="transferred" && o["us"]>record["us"],record["outcomes"])]
 @test !isempty(delayed)
 @test all(all(o->o["status"]!="taken",record["outcomes"]) for record in delayed)
end
