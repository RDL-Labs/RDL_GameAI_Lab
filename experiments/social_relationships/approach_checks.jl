using Test, Serialization
include("../../src/lw/LW.jl")
for (name,path) in ((:social_sight,"perception/social_sight.jl"),(:social_approach_candidates,"decision/social_approach.jl"))
    isdefined(LW,name) || Base.include(LW,joinpath(@__DIR__,"../../src/lw",path))
end
const SDA="npc_a";const SDB="npc_b";const SDC="npc_c"
const SDD=Dict{String,Any}
function approach_world()
    w=LW.world(true)
    w.positions[SDA]=(0.,0.);w.positions[SDB]=(-3.,4.);w.positions[SDC]=(3.,4.)
    w
end
function approach_move(w)
    LW.evaluate_movement(LW.EnergyMovementPolicy(),LW.perceive_movement(w,SDA,SDD(SDA=>0.),Any[],Int[]))
end
function approach_roundtrip(value)
    io=IOBuffer();serialize(io,value);seekstart(io);deserialize(io)
end

@testset "social sight is current, coarse, and physically bounded" begin
    w=approach_world();view=LW.social_sight(w,SDA,0.,0)
    @test view["actor"]==SDA && view["source"]=="ob:0:$SDA"
    @test Set(p["ref"] for p in view["peers"])==Set([SDB,SDC])
    @test all(p->p["range_lower"]==4. && p["range_upper"]==8. && p["distance"]==6.,view["peers"])
    @test all(p->!p["contact"] && abs(p["angle"])==30.,view["peers"])
    @test all(p->Set(keys(p))==Set(["ref","angle","range_lower","range_upper","distance","contact","expression"]),view["peers"])
    # Internal body, food holdings and hearing are not remote visual evidence.
    w.inventory[SDB]=200;w.bodies[SDB]=LW.Body(1.,.9,0.,.7);w.hearing[SDB]=false
    @test LW.social_sight(w,SDA,0.,0)==view
    @test isempty(LW.social_sight(w,SDA,180.,0)["peers"])
    w.positions[SDB]=(0.,13.);w.positions[SDC]=(0.,-2.)
    @test isempty(LW.social_sight(w,SDA,0.,0)["peers"])
    w.positions[SDB]=(0.,5.);w.positions[SDC]=(30.,30.)
    push!(w.obstacles,LW.RDLMigrationProbe.Circle(0.,2.5,.5))
    @test isempty(LW.social_sight(w,SDA,0.,0)["peers"])
    empty!(w.obstacles);w.positions[SDB]=(0.,1.)
    @test only(LW.social_sight(w,SDA,0.,0)["peers"])["contact"]
    @test_throws ErrorException LW.social_sight(w,SDA,NaN,0)
    @test_throws ErrorException LW.social_sight(w,SDA,0.,-1)
    @test_throws ErrorException LW.social_sight(w,SDA,0.,0;half_fov=0.)
end

@testset "experience opens a food-purpose approach, not a social reward" begin
    w=approach_world();view=LW.social_sight(w,SDA,0.,0);move=approach_move(w)
    relations=LW.social_relations_state(SDA)
    for i in 1:6
        LW.social_relation_event!(relations,SDB,"aid_received","good-$i",i;outcome="given")
        LW.social_relation_event!(relations,SDC,"aid_received","bad-$i",i;outcome="refuse")
    end
    loop=LW.BasicLoop("$SDA:food";probabilistic=true,seed=9)
    before=deepcopy(relations);inventory=copy(w.inventory)
    narrow=LW.social_approach_candidates(view,move,relations,loop,0;food_value=2.)
    @test length(narrow)==1 && only(narrow)["social_peer"]==SDB
    @test only(narrow)["question"]=="social_contact" && only(narrow)["action"]=="walk"
    @test relations==before && w.inventory==inventory && loop.trial===nothing
    loop.H=8.
    wide=LW.social_approach_candidates(view,move,relations,loop,0;food_value=2.)
    @test length(wide)==2 && Set(c["social_peer"] for c in wide)==Set([SDB,SDC])
    @test wide[1]["social_expected_gain"]>wide[2]["social_expected_gain"]
    @test wide[1]["priority"]>wide[2]["priority"]
    @test isempty(LW.social_approach_candidates(view,move,relations,loop,0;food_value=0.))
    @test isempty(LW.social_approach_candidates(view,move,nothing,loop,0;food_value=2.))
    @test_throws ErrorException LW.social_approach_candidates(view,move,relations,loop,1;food_value=2.)
    @test_throws ErrorException LW.social_approach_candidates(view,move,relations,loop,0;food_value=-1.)
    @test_throws ErrorException LW.social_approach_candidates(view,move,LW.social_relations_state(SDB),loop,0;food_value=2.)
    blocked=deepcopy(move);foreach(r->r["cost"]=nothing,blocked["energy"]["rows"])
    @test isempty(LW.social_approach_candidates(view,blocked,relations,loop,0;food_value=2.))
    # Ordinary navigation remains in the same probability distribution.
    all_options=vcat(LW.search_candidates(move,nothing,loop),wide)
    probabilities=LW.method_distribution(loop,all_options)
    @test length(probabilities)==length(all_options) && all(>(0.),probabilities)
    @test sum(probabilities)≈1.
    @test relations==before && w.inventory==inventory
    saved=approach_roundtrip((view=view,relations=relations,loop=loop,move=move))
    @test LW.social_approach_candidates(saved.view,saved.move,saved.relations,saved.loop,0;food_value=2.)==wide
end

@testset "contact evidence never credits a gift or tracks an unseen peer" begin
    w=approach_world();relation=LW.social_relations_state(SDA)
    loop=LW.BasicLoop("$SDA:food";probabilistic=true)
    view=LW.social_sight(w,SDA,0.,0)
    choices=LW.social_approach_candidates(view,approach_move(w),relation,loop,0)
    @test !isempty(choices)
    choice=first(choices);peer=choice["social_peer"];other=peer==SDB ? SDC : SDB
    @test LW.social_approach_evidence(choice,view)===nothing
    w.positions[peer]=(0.,1.);w.positions[other]=(30.,30.)
    contact=LW.social_sight(w,SDA,0.,1_000_000)
    before=deepcopy(relation);stock=copy(w.inventory)
    @test LW.social_approach_evidence(choice,contact)===true
    @test isempty(LW.social_approach_candidates(contact,approach_move(w),relation,loop,1_000_000))
    @test relation==before && w.inventory==stock
    w.positions[peer]=(0.,-5.)
    unseen=LW.social_sight(w,SDA,0.,2_000_000)
    @test LW.social_approach_evidence(choice,unseen)===nothing
    @test isempty(LW.social_approach_candidates(unseen,approach_move(w),relation,loop,2_000_000))
    bad=deepcopy(contact);bad["actor"]=SDB
    @test_throws ErrorException LW.social_approach_evidence(choice,bad)
end

@testset "learned food consequences combine with the owner's current taste" begin
    w=approach_world();view=LW.social_sight(w,SDA,0.,0);move=approach_move(w)
    relation=LW.social_relations_state(SDA;relational=true)
    situation=SDD("need"=>.5)
    for i in 1:4
        LW.social_relation_event!(relation,SDB,"aid_received","fruit-$i",i;
            outcome="given",food_kind=1,value=.3,context=situation)
        LW.social_relation_event!(relation,SDC,"aid_received","meal-$i",i;
            outcome="given",food_kind=4,value=.3,context=situation)
    end
    loop=LW.BasicLoop("$SDA:food";probabilistic=true,seed=5)
    fruit=LW.social_approach_candidates(view,move,relation,loop,0;
        food_values=[4.,1.,1.,.5],context=situation)
    meal=LW.social_approach_candidates(view,move,relation,loop,0;
        food_values=[.5,1.,1.,4.],context=situation)
    @test only(fruit)["social_peer"]==SDB && only(meal)["social_peer"]==SDC
    @test only(fruit)["social_conditional_value"]==4. && only(meal)["social_conditional_value"]==4.
    @test only(fruit)["social_probability"]≈only(meal)["social_probability"]
    @test isempty(LW.social_approach_candidates(view,move,relation,loop,0;food_values=zeros(4)))
    @test_throws ErrorException LW.social_approach_candidates(view,move,relation,loop,0;food_values=[1.,2.])
    # Once the owner has seen the same evidence, hidden changes in the other
    # body's taste/needs/stock cannot enter this pure proposal calculation.
    w.inventory[SDB]=0;w.bodies[SDB]=LW.Body(1.,.9,0.,.7)
    @test LW.social_approach_candidates(LW.social_sight(w,SDA,0.,0),move,relation,loop,0;
        food_values=[4.,1.,1.,.5],context=situation)==fruit
end
