include("checks.jl")
using Serialization
@testset "exchange relations generalize observed bundles" begin
    s=LW.incidental_item_state(ITEM_A,19)
    f=item_fixture(objects=[placed_item(1,1;owner=ITEM_A,location="held"),
        placed_item(2,3;owner=ITEM_B,location="held")])
    v=item_view(f,ITEM_A)
    give=LW.item_exchange_bundle(v,[1],zeros(Int,4))
    want=LW.item_exchange_bundle(v,[2],[4,0,0,0])
    p=LW.D("exchange_give"=>give,"exchange_want"=>want,"partner"=>ITEM_B,
        "action"=>"item_offer","context"=>LW.D("need"=>0.))
    feature=only(give["items"])
    @test LW.item_exchange_option(s,feature)==0
    for status in ("offered","expired","unavailable")
        LW.item_exchange_learn!(s,p,LW.D("status"=>status,"us"=>1))
    end
    @test isempty(get(s,"exchange_relations",[]))
    LW.item_exchange_learn!(s,p,LW.D("status"=>"exchanged","us"=>2))
    @test length(s["exchange_relations"])==1
    m=only(s["exchange_relations"])
    @test m["successes"]==1 && m["failures"]==0
    @test !haskey(only(m["give"]["items"]),"ref")
    @test !haskey(only(m["give"]["items"]),"kind")
    e=LW.item_exchange_recall(s,give,want,ITEM_B,p["context"],0.)
    other=LW.item_exchange_recall(s,give,want,ITEM_C,p["context"],0.)
    @test e.successes==1 && 0<other.successes<e.successes
    near=deepcopy(give);near["items"][1]["size"]*=1.05
    @test 0<LW.item_exchange_bundle_fit(s,give,near)<1
    value=LW.item_exchange_option(s,feature;stock=zeros(Int,4),weights=ones(4))
    @test value>LW.incidental_item_interest(feature)
    @test LW.item_subjective_values(s,v;stock=zeros(Int,4),weights=ones(4))[1]>LW.item_subjective_values(LW.incidental_item_state(ITEM_A),v)[1]
    context=LW.D("load_fraction"=>0.,"capacity_mass"=>10.,"capacity_size"=>10.)
    @test LW.incidental_item_prediction(s,feature,context,0.;stock=zeros(Int,4),weights=ones(4)).novelty==value
    LW.item_exchange_learn!(s,p,LW.D("status"=>"declined","us"=>3))
    @test only(s["exchange_relations"])["failures"]==1
    @test LW.item_exchange_option(s,feature;stock=zeros(Int,4),weights=ones(4))<value
    # Changed executor identity still binds the visually similar object.
    renamed=deepcopy(v["own"]["held"]);renamed[1]["ref"]=999
    @test LW.item_exchange_bind(s,give["items"],renamed)==[999]
    io=IOBuffer();serialize(io,s);seekstart(io);restored=deserialize(io)
    @test LW.incidental_item_snapshot(restored)==LW.incidental_item_snapshot(s)
    # Bounded memory and no recursive output revaluation.
    base=LW.item_exchange_option(s,feature;stock=zeros(Int,4),weights=ones(4))
    for n in 1:140
        q=deepcopy(p);q["partner"]="peer-$n"
        LW.item_exchange_learn!(s,q,LW.D("status"=>"declined","us"=>n+3))
    end
    @test length(s["exchange_relations"])==128
    @test LW.item_exchange_option(s,feature;stock=zeros(Int,4),weights=ones(4))==base
end

@testset "learn only resolved execution once; recall learned food request" begin
    # Synthetic prior is a test fixture, not a configured production trade.
    f=barter_fixture();s=LW.incidental_item_state(ITEM_A,9);v=item_view(f,ITEM_A)
    give=LW.item_exchange_bundle(v,[1],zeros(Int,4))
    want=LW.item_exchange_bundle(v,Int[],[4,0,0,0])
    prior=LW.D("exchange_give"=>give,"exchange_want"=>want,"partner"=>ITEM_B,
        "action"=>"item_offer","context"=>LW.D("need"=>0.))
    LW.item_exchange_learn!(s,prior,LW.D("status"=>"exchanged","us"=>0))
    found=false
    for seed in 1:256
        trial=deepcopy(s);trial["loop"].seed=seed
        p=LW.item_social_plan!(trial,v,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],1)
        p===nothing && continue
        if p["action"]=="item_offer" && p["give_items"]==[1] && p["want_food"]==[4,0,0,0]
            found=true
            @test p["exchange_evidence"]["successes"]>0
            o=item_act(f,ITEM_A,p["action"],1;target=p["target"],give_items=p["give_items"],want_items=p["want_items"],give_food=p["give_food"],want_food=p["want_food"])
            @test LW.item_social_executed!(trial,p,o)
            @test sum(m["successes"] for m in trial["exchange_relations"])==1
            item_act(f,p["target"],"item_decline",2;offer_id=o["offer_id"])
            LW.item_social_observe!(trial,item_view(f,ITEM_A;now=3))
            after=deepcopy(LW.incidental_item_snapshot(trial))
            @test sum(m["failures"] for m in trial["exchange_relations"])==1
            LW.item_social_observe!(trial,item_view(f,ITEM_A;now=4))
            @test LW.incidental_item_snapshot(trial)==after
            break
        end
    end
    @test found
end
