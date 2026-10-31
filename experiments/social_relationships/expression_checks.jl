using Test, Serialization
include("../../src/lw/LW.jl")
const EA="npc_a";const EB="npc_b";const EC="npc_c"
function expression_world()
    w=LW.world(false);empty!(w.obstacles)
    w.positions[EA]=(0.,0.);w.positions[EB]=(0.,.75);w.positions[EC]=(100.,100.)
    w.bodies[EA]=LW.Body(10.,0.,95.,0.);w.bodies[EB]=LW.Body(10.,0.,0.,0.)
    w.inventory[EA]=0;w.inventory[EB]=0
    w
end
function expression_relation(seed)
    s=LW.social_relations_state(EA;relational=true)
    s["visual_aid"]=LW.visual_aid_state(EA;seed);s
end
@testset "public expressions are ambiguous and visually bounded" begin
    calm=LW.configured_expression(LW.Body(10.,0.,95.,0.))
    @test calm==(calm=1.,distress=0.,fear=0.)
    @test LW.configured_expression(LW.Body(10.,0.,30.,0.)).distress==.5
    @test LW.configured_expression(LW.Body(10.,.5,95.,0.)).distress==.5
    @test LW.configured_expression(LW.Body(10.,0.,95.,.5)).distress==.5
    @test LW.configured_expression(LW.Body(10.,0.,95.,0.);fear=.75).fear==.75
    w=expression_world();v=LW.social_sight(w,EA,0.,0)
    face=only(v["peers"])["expression"]
    @test Set(keys(face))==Set((:calm,:distress,:fear)) && face.distress==1
    @test !haskey(only(v["peers"]),"body")
    w.bodies[EB]=LW.Body(10.,0.,2.,0.)
    @test only(LW.social_sight(w,EA,0.,0)["peers"])["expression"]==face
    @test isempty(LW.social_sight(w,EA,180.,0)["peers"])
    w.positions[EB]=(0.,5.)
    @test only(LW.social_sight(w,EA,0.,0)["peers"])["expression"]===nothing
    push!(w.obstacles,LW.RDLMigrationProbe.Circle(0.,2.,.5))
    @test isempty(LW.social_sight(w,EA,0.,0)["peers"])
end

@testset "optional assistance preserves own food and rechecks contact" begin
    w=expression_world();v=LW.social_sight(w,EA,0.,0);chosen=nothing;skipped=0
    for seed in 1:32
        rel=expression_relation(seed)
        p=LW.visual_aid_plan!(rel,v,w.bodies[EA],nothing,[6,0,0,0],Int[],0;at_home=true)
        if p===nothing;skipped+=1;else;chosen=(rel,p);end
    end
    @test chosen!==nothing && skipped>0
    rel,p=chosen
    @test p["action"]=="retrieve" && p["target"]==EB
    @test p["context"]["distress"]==1 && p["question"]=="food_delivered"
    @test LW.visual_aid_plan!(expression_relation(1),v,w.bodies[EA],nothing,[1,0,0,0],Int[],0;at_home=true)===nothing
    @test LW.visual_aid_plan!(expression_relation(1),v,w.bodies[EA],nothing,[6,0,0,0],[1],0;at_home=false)===nothing
    @test LW.visual_aid_plan!(expression_relation(1),v,w.bodies[EA],nothing,[0,0,6,0],Int[],0;at_home=true)===nothing
    @test LW.visual_aid_plan!(expression_relation(1),v,LW.Body(10.,0.,40.,0.),nothing,[6,0,0,0],Int[],0;at_home=true)===nothing
    @test LW.visual_aid_plan!(expression_relation(1),v,w.bodies[EA],nothing,[6,0,0,0],Int[],0;at_home=true,contacts=[Dict("ref"=>EB,"holding_food"=>true)])===nothing
    @test !LW.visual_aid_executed!(rel,p,"performed") # retrieve is not completed help
    copied=deepcopy(rel)
    w.positions[EB]=(0.,5.)
    @test LW.visual_aid_plan!(copied,LW.social_sight(w,EA,0.,1),w.bodies[EA],nothing,[5,0,0,0],[1],1;at_home=true)===nothing
    @test copied["visual_aid"]["abandoned"]==1 && copied["visual_aid"]["loop"].trial===nothing
    w.positions[EB]=(0.,.75)
    next=LW.visual_aid_plan!(rel,LW.social_sight(w,EA,0.,1),w.bodies[EA],nothing,[5,0,0,0],[1],1;at_home=true)
    @test next["action"]=="give"
    w.inventory[EA]=1
    result=LW.communicate!(w,EA,"voluntary", "give",EB;food_kind=1,unsolicited=true)
    @test result["status"]=="transferred" && w.inventory[EA]==0 && w.inventory[EB]==1
    @test LW.communicate!(w,EA,"voluntary","give",EB;food_kind=1,unsolicited=true)==result
    @test w.inventory[EB]==1 && isempty(w.answered)
    @test LW.visual_aid_executed!(rel,next,result["status"])
    @test !LW.visual_aid_executed!(rel,next,result["status"])
    @test rel["visual_aid"]["transferred"]==1
    @test only(w.inbox[EB])["reply_to"]===nothing # no request manufactured
    @test_throws ErrorException LW.communicate!(w,EA,"voluntary","give",EB;food_kind=1)
end

@testset "expression context joins existing relation correspondence" begin
    rel=expression_relation(1)
    @test_throws ErrorException LW.social_mb_context(Dict("distress"=>1.1))
    @test_throws ErrorException LW.social_mb_context(Dict("reserve"=>0.))
    for i in 1:4
        LW.social_relation_event!(rel,EB,"aid_given","observed:$i",i;outcome="transferred",context=Dict("distress"=>1.,"fear"=>0.))
    end
    same=LW.social_mb_predict(rel,EB,"aid_given";situation=Dict("distress"=>1.,"fear"=>0.))
    different=LW.social_mb_predict(rel,EB,"aid_given";situation=Dict("distress"=>0.,"fear"=>1.))
    @test same["probability"]>different["probability"]>.5
end

@testset "LW silent store-to-hand-to-peer assistance and restart" begin
    clock=merge(LW.native_clock(),(day_us=128_000_000,phase_boundaries_us=[0,0,128_000_000,128_000_000],quiet_night_us=128_000_000))
    scene=merge(LW.native_scene(19),(hearing=false,positions=[[0.,0.],[0.,.5],[100.,100.]],home=[0.,0.],
        food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
        initial_inventory=[0,0,0],initial_inventory_kinds=[Int[],Int[],Int[]],
        initial_personal_stock=[6,0,0],
        initial_personal_food_counts=Dict(Symbol(EA)=>[6,0,0,0],Symbol(EB)=>[0,0,0,0],Symbol(EC)=>[0,0,0,0]),
        reserve=[95.,20.,95.],typed_food=true,social_relationships=true))
    run(seed;kwargs...)=LW.lw_day(scene,clock;days=2,basic_loop=true,landmark_routes=true,food_body=true,social_response=true,choice_seed=seed,kwargs...)
    successes=Int[]
    for seed in 0:3
        r=run(seed);m=r["social_relationships"][EA]["visual_aid"]
        @test r["initial_food"]==6
        m["transferred"]>0 && push!(successes,seed)
        @test r["initial_food"]==r["consumed"]+sum(a["inventory"]+a["personal_stock"] for a in values(r["final_agents"]))
        @test m["transferred"]<=5 # preserves own next meal
        if m["transferred"]>0
            @test r["social_relationships"][EB]["peers"][EA]["aid_received"]["given"]>0
            @test any(e->e["action"]=="retrieve",r["events"])
            @test any(e->e["action"]=="give" && e["status"]=="transferred",r["events"])
        end
    end
    @test !isempty(successes)
    if !isempty(successes)
        mktempdir() do dir
            a=run(first(successes);checkpoint_dir=dir)
            b=run(first(successes);resume_from=joinpath(dir,"day-001.jls"))
            @test a["social_relationships"]==b["social_relationships"]
            @test a["food_resources"]==b["food_resources"]
        end
    end
end
