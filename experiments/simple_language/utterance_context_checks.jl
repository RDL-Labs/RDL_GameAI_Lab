include("../portable_items/checks.jl")
include("trade_observation.jl")
include("utterance_context.jl")
@testset "All utterances bind perceived context without semantic oracle" begin
    f=item_fixture(objects=[placed_item(1,1;x=0.,z=2.),placed_item(2,2;x=1.,z=2.),placed_item(3,3;x=0.,z=-3.)])
    f.w.positions[ITEM_A]=(0.,2.);f.w.positions[ITEM_B]=(1.,2.);f.w.positions[ITEM_C]=(0.,0.)
    relation=LW.social_relations_state(ITEM_C;relational=true)
    baseline=deepcopy(relation);words=ObservedVocabulary()
    # Sender roles differ; receiver applies exactly the same rule.
    for (i,role) in enumerate((:attention,:initiative,:response,:free))
        event=(id="utterance-$i",actor=ITEM_A,role=role,text="ネポ",motion=nothing,appearances=String[])
        observed=receive_utterance_context!(relation,words,f.w,ITEM_C,0.,event,i;items=f.s)
        @test observed.speaker==ITEM_A
        @test length(observed.objects)==2
        @test all(!haskey(o,"kind") && !haskey(o,"owner") for o in observed.objects)
        @test !remember_utterance_context!(relation,words,observed)
    end
    node=only(values(relation["utterance_mb"]["nodes"]))
    @test node["samples"]==4
    @test sum(values(node["appearance_support"]))≈4
    @test observed_word_prediction(words,"ネポ").status=="ambiguous"
    @test all(relation[k]==v for (k,v) in baseline) # no aid/liking/reward changes
    event=(id="voice-only",actor=ITEM_A,text="ネポ",motion=nothing,appearances=["hidden-food"])
    unseen=receive_utterance_context!(relation,words,f.w,ITEM_C,180.,event,5;items=f.s)
    @test unseen.speaker===nothing
    @test !("hidden-food" in unseen.appearances)
    @test length(relation["utterance_mb"]["nodes"])==2
    @test receive_utterance_context!(relation,words,f.w,ITEM_C,0.,merge(event,(id="busy",)),6;items=f.s,attending=false)===nothing
    f.w.hearing[ITEM_C]=false
    @test receive_utterance_context!(relation,words,f.w,ITEM_C,0.,merge(event,(id="deaf",)),7;items=f.s)===nothing
    f.w.hearing[ITEM_C]=true
    path=tempname();serialize(path,(relation,words));restored_relation,restored_words=deserialize(path)
    @test restored_relation==relation
    @test !remember_utterance_context!(restored_relation,restored_words,unseen)
    @test length(restored_relation["utterance_mb"]["receipts"])==5
    # Read boundaries: editing a later world descriptor cannot rewrite memory.
    saved=deepcopy(relation["utterance_mb"])
    f.s["items"][1]["color"]="changed"
    @test relation["utterance_mb"]==saved
    report=(speaker_known_samples=node["samples"],association_support=node["appearance_support"],
        unknown_speaker_retained=unseen.speaker===nothing,language_prediction=observed_word_prediction(words,"ネポ"),
        existing_relationship_unchanged=all(relation[k]==v for (k,v) in baseline))
    write(joinpath(@__DIR__,"utterance_context_result.json"),JSON3.write(report))
end
