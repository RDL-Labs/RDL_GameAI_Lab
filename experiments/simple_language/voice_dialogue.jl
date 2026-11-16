# Local-only adapter; caller loads LW and trade_observation.jl.
include("voice_broadcast.jl")
# 暫定固定 response vocabulary/costs, not learned production or physiology.
# Replace with personal production/cost forecasts later. No trade commitment.
const VOICE_DIALOGUE=(attention_cost=.5,reply_cost=.4,clarification_value=1.,
 orient_us=1_000_000,reply_volume=1.,reply_us=2_000_000,
 interested="話を聞きたい",clarify="もう一度？")
mutable struct VoiceListener
 vocabulary::ObservedVocabulary
 attention::LW.BasicLoop
 response::LW.BasicLoop
 yaw::Float64
 focus_cost::Float64
 interests::Dict{String,Float64}
 processed::Dict{String,Any}
end
VoiceListener(id;seed=1,focus_cost=0.,interests=Dict{String,Float64}(),vocabulary=ObservedVocabulary())=
 VoiceListener(vocabulary,LW.BasicLoop("$id:voice-attention";probabilistic=true,seed),
 LW.BasicLoop("$id:voice-response";probabilistic=true,seed),0.,focus_cost,interests,Dict{String,Any}())
function voice_select!(loop,scores,id)
 candidates=[LW.D("method"=>name,"priority"=>score,"question"=>"communication_opportunity") for (name,score) in scores]
 probabilities=LW.method_distribution(loop,candidates)
 selected=LW.choose_method!(loop,candidates,id)
 # Local selection/execution isn't a completed trade and earns no reward.
 LW.resolve_method!(loop,id,nothing,nothing;creditable=false,goal_H_increment=0.)
 (method=selected["method"],probabilities=Dict(first(scores[i])=>probabilities[i] for i in eachindex(scores)))
end
function voice_word_matches(memory,text)
 [(word=String(token),prediction=observed_word_prediction(memory,String(token))) for token in unique(split(text))]
end
function voice_listener_step!(world,listener,mind,event;now_us=event.start_us)
 if haskey(mind.processed,event.id)
  prior=mind.processed[event.id]
  prior.event==event || error("conflicting voice event ID")
  return prior.result
 end
 event.duration_us>0 || throw(ArgumentError("positive utterance duration required"))
 event.start_us<=now_us<event.start_us+event.duration_us || return (status="inactive",)
 cue=voice_observation(world,event.source,listener,event.text;volume=event.volume,attending=false)
 result=if cue===nothing
  (status="not_heard",)
 else
  salience=log1p(cue.strength/VOICE_BROADCAST.notice_strength)
  attention=voice_select!(mind.attention,["orient"=>LW.relational_transition(0.,salience;cost=VOICE_DIALOGUE.attention_cost+mind.focus_cost).expected,"continue"=>0.],event.id*":attention")
  if attention.method=="continue"
   (status="continued_task",cue=cue,attention=attention)
  else
   mind.yaw=cue.bearing
   # Only the remaining live utterance can be heard after orienting. No retroactive text.
   listen_us=now_us+VOICE_DIALOGUE.orient_us
   words=listen_us<event.start_us+event.duration_us ? voice_observation(world,event.source,listener,event.text;volume=event.volume,attending=true) : nothing
   matches=words===nothing ? [] : voice_word_matches(mind.vocabulary,words.text)
   known=filter(m->m.prediction.status=="provisional",matches)
   expected_interest=isempty(known) ? 0. : maximum(get(mind.interests,m.prediction.appearance,0.)*m.prediction.share for m in known)
   scores=Pair{String,Float64}["silent"=>0.,"clarify"=>LW.relational_transition(0.,isempty(known) ? VOICE_DIALOGUE.clarification_value : 0.;cost=VOICE_DIALOGUE.reply_cost+mind.focus_cost).expected]
   isempty(known) || push!(scores,"interested"=>LW.relational_transition(0.,expected_interest;cost=VOICE_DIALOGUE.reply_cost+mind.focus_cost).expected)
   response=voice_select!(mind.response,scores,event.id*":response")
   reply=response.method=="silent" ? nothing : (id=event.id*":reply:"*listener,source=listener,
    text=response.method=="interested" ? VOICE_DIALOGUE.interested : VOICE_DIALOGUE.clarify,
    volume=VOICE_DIALOGUE.reply_volume,start_us=listen_us,duration_us=VOICE_DIALOGUE.reply_us)
   (status="oriented",cue=cue,attention=attention,words=words,matches=matches,response=response,reply=reply)
  end
 end
 mind.processed[event.id]=(event=event,result=result)
 result
end
function voice_dialogue!(world,listeners,event)
 results=Dict(a=>voice_listener_step!(world,a,listeners[a],event) for a in sort(collect(keys(listeners))) if a!=event.source)
 # Reply emission is broadcast too. No automatic understanding or recursive reply loop.
 replies=Dict(a=>broadcast_voice(world,a,r.reply.text;volume=r.reply.volume,
  attention=Dict(event.source=>true)) for (a,r) in results if hasproperty(r,:reply) && r.reply!==nothing)
 (listeners=results,reply_reception=replies)
end
