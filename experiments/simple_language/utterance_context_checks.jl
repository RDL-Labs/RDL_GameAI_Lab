include("../portable_items/checks.jl")
include("trade_observation.jl")
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
include("role_probe.jl")
include("trade_channels.jl")
include("voice_broadcast.jl")
@testset "Live common receiver hooks" begin
    f=item_fixture(objects=[placed_item(1,1;x=0.,z=2.)])
    f.w.positions[ITEM_A]=(0.,2.);f.w.positions[ITEM_B]=(1.,2.);f.w.positions[ITEM_C]=(0.,0.)
    relations=Dict(a=>LW.social_relations_state(a;relational=true) for a in LW.IDS)
    memories=Dict(a=>TradeChannelObserver() for a in LW.IDS)
    yaw=Dict(a=>0. for a in LW.IDS)
    bind_utterance_context!(relations,memories,f.s,ITEM_HOME,10,yaw)
    try
        for (i,role) in enumerate((:attention,:initiative,:response))
            event=(id="live-$i",actor=ITEM_A,role=role,text="ネポ",motion=nothing,appearances=String[])
            observed=role_public_observation(f.w,ITEM_C,0.,event)
            @test observed.speaker==ITEM_A
            @test haskey(relations[ITEM_C]["utterance_mb"]["receipts"],event.id)
            learn_observed_words!(memories[ITEM_C].words,observed)
        end
        @test observed_word_prediction(memories[ITEM_C].words,"ネポ").samples==3
        voice_observation(f.w,ITEM_A,ITEM_C,"呼びかけ";attending=true,event_id="broadcast-1")
        broadcast_voice(f.w,ITEM_A,"返答";attention=Dict(ITEM_C=>true),event_id="reply-1")
        @test length(relations[ITEM_C]["utterance_mb"]["receipts"])==5
        @test !haskey(relations[ITEM_B],"utterance_mb")
        path=tempname();serialize(path,relations)
        restored=deserialize(path)
        bind_utterance_context!(restored,memories,f.s,ITEM_HOME,10,yaw)
        voice_observation(f.w,ITEM_A,ITEM_C,"呼びかけ";attending=true,event_id="broadcast-1")
        @test length(restored[ITEM_C]["utterance_mb"]["receipts"])==5
    finally
        UTTERANCE_LIVE_CONTEXT[]=nothing
    end
end
