# 暫定固定: experimental RDL_WANT_VOICE=1 only, default OFF.
# One request/day at an existing trade opportunity; subject comes from own food valuation.
# Known request grammar, direct yaw orientation, first recognized reply, fine rho
# are shortcuts, to be replaced by learned production/attention/partner choice.
# Loaded by the cohort runner AFTER the experimental voice/recognition adapters.
const CONFIGURED_WANT_VOICE=(reply_window_us=8_000_000,volume=1.,wait_scan=0.)
# 暫定固定の語句表。品目の価値は設定しない。将来は発話生成の学習へ置換する。
const CONFIGURED_WANT_WORDS=("果実","肉","生ドングリ","加工ドングリ","生魚","腐敗食料","焼き魚","魚")
configured_want_appearance(kind)=kind==8 ? WANT_FISH.appearance : "request-food-$(kind)"
function configured_want_vocabulary()
 vocabulary=ObservedVocabulary()
 for kind in LW.RDLBody.FOOD_KIND_IDS, i in 1:WANT_FISH.teaching_samples
  learn_observed_words!(vocabulary,(id="request-teaching:$kind:$i",text=CONFIGURED_WANT_WORDS[kind],motion=nothing,appearances=[configured_want_appearance(kind)]))
 end
 vocabulary
end
function configured_want_desire(body,gut,stock;map=nothing,kitchen=nothing,relation=nothing)
 stock===nothing && return nothing
 weights=LW.food_trade_weights(body,gut;map,kitchen)
 security=map===nothing ? food_security(relation) : get(map,"food_security",food_security(relation))
 valuation=LW.trade_valuation_context(body,gut,security,D(),nothing)
 candidates=Any[]
 for kind in LW.RDLBody.FOOD_KIND_IDS
  weights[kind]>0 || continue
  after=copy(stock);after[kind]+=1
  material=weights[kind]*(log1p(after[kind])-log1p(stock[kind]))
  gradient=LW.trade_compound_gradient(stock,after,material,valuation)
  gradient["total"]>0 || continue
  push!(candidates,(kind=kind,gradient=gradient))
 end
 isempty(candidates) && return nothing
 candidates[argmax([c.gradient["total"] for c in candidates])]
end
function configured_want_interest(body,stock,known,words;security=nothing)
 words===nothing && return nothing
 WANT_FISH.request_word in split(words.text) || return nothing
 strengths=Float64[]
 for kind in LW.RDLBody.FOOD_KIND_IDS
  CONFIGURED_WANT_WORDS[kind] in split(words.text) || continue
  any(m->m.prediction.appearance==configured_want_appearance(kind),known) || continue
  stock[kind]>0 || continue
  push!(strengths,log1p(stock[kind])*(1-clamp(LW.trade_food_need(body,nothing,stock;security),0.,1.)))
 end
 isempty(strengths) ? nothing : maximum(strengths)
end
function configured_want_state(ids;fresh=false)
 Dict("listeners"=>Dict(a=>VoiceListener(a;seed=i,vocabulary=a=="npc_e" ? ObservedVocabulary() : configured_want_vocabulary()) for (i,a) in enumerate(ids)),
      "pending"=>Dict{String,Any}(),"last_day"=>Dict{String,Int}(),"records"=>Any[])
end
function configured_want_record!(state,event,actor,now;kwargs...)
 push!(state["records"],D("event"=>event,"actor"=>actor,"us"=>now, (String(k)=>v for (k,v) in kwargs)...))
end
function configured_want_tick!(voice,w,yaw,thinking,foods,relations,roster,now)
 (foods===nothing || relations===nothing) && return
 for caller in sort!(collect(keys(voice["pending"])))
  pending=voice["pending"][caller];event=pending["event"]
  if now>=event.start_us+CONFIGURED_WANT_VOICE.reply_window_us
   configured_want_record!(voice,"expired",caller,now)
   delete!(voice["pending"],caller);continue
  end
  for peer in sort!(collect(keys(voice["listeners"])))
   peer==caller && continue
   peer in thinking || continue
   body=w.bodies[peer]
   body.reserve>0 && body.damage<1 && body.strain<1 || continue
   if !(peer in pending["heard"]) && event.start_us<=now<event.start_us+event.duration_us
    mind=voice["listeners"][peer]
    r=voice_listener_step!(w,peer,mind,event;now_us=now,
     response_interest=(known,words)->configured_want_interest(body,foods.personal[peer],known,words;security=food_security(relations[peer])))
    push!(pending["heard"],peer)
    if r.status=="oriented"
     yaw[peer]=mind.yaw
     if r.reply!==nothing
      push!(pending["replies"],(peer=peer,event=r.reply,interested=r.response.method=="interested"))
     end
    end
    configured_want_record!(voice,"heard_attempt",peer,now;caller,status=r.status)
   end
  end
  # Replies are not delivered before their live emission time. Only thinking,
  # able actors participate; this does not wake sleepers or interrupt workers.
  for reply in pending["replies"]
   reply.peer in pending["delivered"] && continue
   reply.event.start_us<=now<reply.event.start_us+reply.event.duration_us || continue
   reply.peer in thinking && caller in thinking || continue
   push!(pending["delivered"],reply.peer)
   configured_want_record!(voice,"reply",reply.peer,now;caller,interested=reply.interested)
   reply.interested || continue
   cue=voice_observation(w,reply.peer,caller,reply.event.text;volume=reply.event.volume,attending=true)
   cue===nothing && continue
   yaw[caller]=cue.bearing
   memory=get!(()->configured_peer_identity_memory(caller,roster),relations[caller],"identity_observation")
   identity=reply_visual_identity(w,caller,cue,roster,yaw,memory;now)
   configured_want_record!(voice,"recognition",caller,now;peer=reply.peer,status=identity.status)
   if identity.status=="recognized" && pending["identity"]===nothing
    pending["identity"]=identity
   end
  end
 end
end
function configured_want_plan!(voice,day_us,state,observed,body,gut,stock,now;allow_start=true,relation=nothing,kwargs...)
 actor=state["actor"]
 observed===nothing && return nothing
 if !isempty(observed["incoming"])
  return learned_channel_plan!(state,observed,body,gut,stock,now;allow_start,relation,kwargs...)
 end
 pending=get(voice["pending"],actor,nothing)
 if pending!==nothing
  identity=pending["identity"]
  if identity!==nothing
   selected=deepcopy(observed);filter!(==(identity.handle),selected["trade_partners"])
   projected=reply_relation_projection(relation,identity)
   plan=learned_channel_plan!(state,selected,body,gut,stock,now;allow_start,relation=projected,requested_food=get(pending,"requested_food",WANT_FISH.kind),kwargs...)
   reply_relation_record!(relation,projected)
   if plan!==nothing
    plan["request_call_id"]=pending["event"].id
    configured_want_record!(voice,"proposal",actor,now;target=identity.handle,source=plan["source"])
    delete!(voice["pending"],actor)
    return plan
   end
  end
  return D("action"=>"scan","method"=>"voice_request_wait","scan_angle"=>CONFIGURED_WANT_VOICE.wait_scan,"configured_rule"=>"voice_request_wait")
 end
 mind=item_social_state!(state)
 day=div(now,day_us)
 if allow_start && CHANNELS[actor][1] && stock!==nothing &&
    get(voice["last_day"],actor,-1)!=day && observed["outgoing"]===nothing && mind["pending"]===nothing && now>=mind["next_us"]
  desire=configured_want_desire(body,gut,stock;map=get(kwargs,:map,nothing),kitchen=get(kwargs,:kitchen,nothing),relation)
  desire===nothing && return learned_channel_plan!(state,observed,body,gut,stock,now;allow_start,relation,kwargs...)
  voice["last_day"][actor]=day
  # Bound deduplication history to live utterances; completed calls never replay.
  for listener in values(voice["listeners"])
   filter!(p->p.second.event.start_us+CONFIGURED_WANT_VOICE.reply_window_us>now,listener.processed)
  end
  event=(id="want:$actor:$now",source=actor,text=CONFIGURED_WANT_WORDS[desire.kind]*" 欲しい",volume=CONFIGURED_WANT_VOICE.volume,start_us=now,duration_us=WANT_FISH.utterance_us)
  voice["pending"][actor]=D("event"=>event,"requested_food"=>desire.kind,"heard"=>Set{String}(),"replies"=>Any[],"delivered"=>Set{String}(),"identity"=>nothing)
  configured_want_record!(voice,"call",actor,now;id=event.id,requested_food=desire.kind,text=event.text,gradient=desire.gradient)
  return D("action"=>"scan","method"=>"voice_request_call","scan_angle"=>CONFIGURED_WANT_VOICE.wait_scan,"configured_rule"=>"voice_request_call")
 end
 learned_channel_plan!(state,observed,body,gut,stock,now;allow_start,relation,kwargs...)
end
