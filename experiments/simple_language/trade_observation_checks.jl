using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
include("trade_observation.jl")
const SPEAKER, RECEIVER, OBSERVER = LW.IDS[1:3]
# 暫定固定教材: actors demonstrate named objects and a transfer; no autonomous
# speaking/teaching policy. Never enabled in normal LW. Replace with public action
# events when connecting the living simulation.
function configured_demonstration(w,food,cargo,kind,word,appearance,prefix)
    LW.food_push!(food,SPEAKER,kind,2;deadline=30)
    food.initial[kind]+=1;w.inventory[SPEAKER]+=1;push!(cargo[SPEAKER],prefix)
    shown=(id=prefix*":show",actor=SPEAKER,text=word,motion="show",appearances=[appearance])
    reply=(id=prefix*":reply",actor=RECEIVER,text="",motion="reach",appearances=String[])
    index=length(food.inventory[SPEAKER])
    LW.food_give!(food,SPEAKER,RECEIVER,index)
    push!(cargo[RECEIVER],popat!(cargo[SPEAKER],index))
    w.inventory[SPEAKER]-=1;w.inventory[RECEIVER]+=1
    transferred=(id=prefix*":transfer",actor=RECEIVER,text=word,motion="receive",appearances=[appearance])
    [shown,reply,transferred]
end
w=LW.world(true);empty!(w.obstacles)
for actor in LW.IDS;w.inventory[actor]=0;w.positions[actor]=(0.,0.);end
w.positions[SPEAKER]=(-.5,2.);w.positions[RECEIVER]=(.5,2.)
stores=Dict(a=>0 for a in LW.IDS);cargo=Dict(a=>String[] for a in LW.IDS)
food=LW.food_resources((typed_food=true,food_batch_expiry=true,),w,Any[],Int[],0,stores)
memory=ObservedVocabulary();observations=Any[]
@testset "public trade observation and empty vocabulary" begin
    @test observed_word_prediction(memory,"ミナ").status=="unknown"
    for (kind,word,appearance) in ((1,"ミナ","round-red"),(3,"トコ","small-brown"))
        for event in configured_demonstration(w,food,cargo,kind,word,appearance,word)
            observation=observe_trade_event(w,OBSERVER,0.,event)
            push!(observations,observation);learn_observed_words!(memory,observation)
        end
        @test observed_word_prediction(memory,word).appearance==appearance
    end
    @test LW.food_audit!(food,w,Int[],0,stores)===nothing
    @test LW.food_age_audit!(food)===nothing
    @test w.inventory[OBSERVER]==0
    saved=deepcopy(memory.evidence)
    @test !learn_observed_words!(memory,first(observations))
    @test memory.evidence==saved
    event=(id="control",actor=SPEAKER,text="ミナ",motion="show",appearances=["round-red"])
    w.hearing[OBSERVER]=false
    control=ObservedVocabulary();learn_observed_words!(control,observe_trade_event(w,OBSERVER,0.,event))
    @test isempty(control.evidence)
    w.hearing[OBSERVER]=true;w.positions[OBSERVER]=(100.,100.)
    @test observe_trade_event(w,OBSERVER,0.,event)===nothing
    w.positions[OBSERVER]=(0.,0.)
    @test observe_trade_event(w,OBSERVER,0.,event;attending=false)===nothing
    unseen=observe_trade_event(w,OBSERVER,180.,event)
    @test unseen.text=="ミナ" && isempty(unseen.appearances)
    learn_observed_words!(control,unseen);@test isempty(control.evidence)
    ambiguous=ObservedVocabulary()
    for i in 1:2
        learn_observed_words!(ambiguous,(id="amb$i",text="ナモ",appearances=["round-red","small-brown"]))
    end
    @test observed_word_prediction(ambiguous,"ナモ").status=="ambiguous"
    for i in 1:3
        learn_observed_words!(ambiguous,(id="clear$i",text="ナモ",appearances=["small-brown"]))
    end
    @test observed_word_prediction(ambiguous,"ナモ").appearance=="small-brown"
    io=IOBuffer();serialize(io,memory);seekstart(io);restored=deserialize(io)
    @test !learn_observed_words!(restored,first(observations))
    @test restored.evidence==memory.evidence
end
write(joinpath(@__DIR__,"trade_observation_result.json"),JSON3.write((scope="local fixed demonstrations; empty observer vocabulary; no autonomous speech",observations=observations,predictions=Dict(word=>observed_word_prediction(memory,word) for word in ("ミナ","トコ")))))
