using Test,JSON3
include("../../src/lw/LW.jl")
include("trade_observation.jl")
include("voice_dialogue.jl")
# Authored public learning episodes, not a built-in word-to-food dictionary.
function voice_taught(word="モ",appearance="fish-form")
 memory=ObservedVocabulary()
 for i in 1:3
  learn_observed_words!(memory,(id="seen-$i",text=word,motion=nothing,appearances=[appearance]))
 end
 memory
end
world=(positions=Dict("caller"=>(0.,0.),"known"=>(2.,0.),"unknown"=>(0.,3.),"busy"=>(3.,0.),"faint"=>(12.,0.),"far"=>(40.,0.)),
 hearing=Dict(a=>true for a in ("caller","known","unknown","busy","faint","far")))
event=(id="call-1",source="caller",text="モ",volume=1.,start_us=0,duration_us=3_000_000)
rows=Any[]
@testset "heard -> attention -> learned recognition -> audible reply" begin
 for seed in 1:16
  minds=Dict(a=>VoiceListener(a;seed,focus_cost=a=="busy" ? 8. : 0.,
    vocabulary=a=="unknown" ? ObservedVocabulary() : voice_taught(),interests=Dict("fish-form"=>3.)) for a in keys(world.positions) if a!="caller")
  before=deepcopy(world);memory_before=deepcopy(minds["known"].vocabulary.evidence)
  result=voice_dialogue!(world,minds,event)
  @test world==before
  @test minds["known"].vocabulary.evidence==memory_before
  @test result.listeners["far"].status=="not_heard"
  @test !haskey(result.reply_reception,"far")
  @test !hasproperty(result.listeners["unknown"],:response) || result.listeners["unknown"].response.method!="interested"
  @test !hasproperty(result.listeners["faint"],:words) || result.listeners["faint"].words.text==""
  sequence=minds["known"].attention.sequence
  @test voice_listener_step!(world,"known",minds["known"],event)==result.listeners["known"]
  @test minds["known"].attention.sequence==sequence
  @test_throws ErrorException voice_listener_step!(world,"known",minds["known"],merge(event,(text="different",)))
  @test all(n.reward==0 for n in values(minds["known"].response.methods))
  push!(rows,(seed=seed,result=result))
 end
 @test any(row->hasproperty(row.result.listeners["known"],:reply) && row.result.listeners["known"].reply!==nothing,rows)
 @test any(row->haskey(row.result.reply_reception,"known") && row.result.reply_reception["known"]["caller"]!==nothing,rows)
 @test any(row->hasproperty(row.result.listeners["unknown"],:response) && row.result.listeners["unknown"].response.method=="clarify",rows)
 @test count(row->row.result.listeners["busy"].status=="continued_task",rows)>count(row->row.result.listeners["known"].status=="continued_task",rows)
 for seed in 1:16
  mind=VoiceListener("short";seed,vocabulary=voice_taught(),interests=Dict("fish-form"=>3.))
  short=voice_listener_step!(world,"known",mind,merge(event,(duration_us=1,)))
  @test !hasproperty(short,:words) || short.words===nothing
  @test !hasproperty(short,:response) || short.response.method!="interested"
 end
 mind=VoiceListener("expired")
 @test voice_listener_step!(world,"known",mind,event;now_us=3_000_000).status=="inactive"
 @test mind.attention.sequence==0
 alternative=VoiceListener("known";seed=1,vocabulary=voice_taught("ナ"),interests=Dict("fish-form"=>3.))
 alternative_result=voice_listener_step!(world,"known",alternative,event)
 @test alternative_result.status=="oriented"
 @test all(m.prediction.status=="unknown" for m in alternative_result.matches)
 @test alternative_result.response.method!="interested"
 disliked=VoiceListener("known";seed=1,vocabulary=voice_taught(),interests=Dict("fish-form"=>-3.))
 disliked_result=voice_listener_step!(world,"known",disliked,event)
 @test disliked_result.response.probabilities["interested"]<rows[1].result.listeners["known"].response.probabilities["interested"]
end
summary=Dict(a=>Dict("oriented"=>count(row->row.result.listeners[a].status=="oriented",rows),
 "interested"=>count(row->hasproperty(row.result.listeners[a],:response) && row.result.listeners[a].response.method=="interested",rows),
 "clarify"=>count(row->hasproperty(row.result.listeners[a],:response) && row.result.listeners[a].response.method=="clarify",rows)) for a in ("known","unknown","busy","faint","far"))
write(joinpath(@__DIR__,"voice_dialogue_result.json"),JSON3.write((settings=VOICE_DIALOGUE,summary=summary,trials=rows)))
println(JSON3.write(summary))
