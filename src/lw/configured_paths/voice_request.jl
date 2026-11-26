# 暫定固定: experimental RDL_WANT_VOICE=1 only, default OFF.
# One request/day at an existing trade opportunity; subject comes from own food valuation.
# Known request grammar, direct yaw orientation, first recognized reply, fine rho
# are shortcuts, to be replaced by learned production/attention/partner choice.
# Loaded by the cohort runner AFTER the experimental voice/recognition adapters.
const CONFIGURED_WANT_VOICE=(reply_window_us=8_000_000,volume=1.,wait_scan=0.)
# 構築側の読みやすい初期教材名。語の正解表ではなく、個体の語句は自由な記号。
# 品目ID・外見・個体の学習語彙を分離し、発話は語彙記憶から選ぶ。
const CONFIGURED_WANT_WORDS=("果実","肉","生ドングリ","加工ドングリ","生魚","腐敗食料","焼き魚","塩焼き魚")
configured_want_appearance(kind)=kind==8 ? WANT_FISH.appearance : "request-food-$(kind)"
function configured_want_vocabulary(;words=CONFIGURED_WANT_WORDS)
 vocabulary=ObservedVocabulary()
 for kind in LW.RDLBody.FOOD_KIND_IDS, i in 1:WANT_FISH.teaching_samples
  learn_observed_words!(vocabulary,(id="request-teaching:$kind:$i",text=words[kind],motion=nothing,appearances=[configured_want_appearance(kind)]))
 end
 for i in 1:WANT_FISH.teaching_samples
  learn_observed_words!(vocabulary,(id="request-role:$i",text=WANT_FISH.request_word,motion=nothing,appearances=["request-intent"]))
 end
 vocabulary
end
configured_want_recall(map)=LW.trade_request_recall(map)
configured_want_known_food(map,kind)=kind in configured_want_recall(map)
function configured_want_expression(vocabulary,appearance)
 matches=Pair{String,Float64}[]
 for token in keys(vocabulary.evidence)
  prediction=observed_word_prediction(vocabulary,token)
  prediction.status=="provisional" && prediction.appearance==appearance || continue
  push!(matches,token=>prediction.samples*prediction.share)
 end
 isempty(matches) && return nothing
 sort!(matches;by=p->(-p.second,p.first));first(matches).first
end
configured_want_word(vocabulary,kind)=configured_want_expression(vocabulary,configured_want_appearance(kind))
# 暫定固定: request experiment only. A visible contact-range meal exposes its
# food appearance; appearance/category recognition is initial knowledge, not taste.
# Reuse current social sight (FOV, occlusion, light); no new all-world observation.
# Replace this coarse contact gate with learned food-part recognition later.
function configured_want_observe_meal!(maps,social_views,eater,kind,now)
 (maps===nothing || social_views===nothing || !(kind in LW.RDLBody.FOOD_KIND_IDS)) && return
 appearance=LW.RDLBody.FOOD_APPEARANCE[kind]
 for (observer,sight) in social_views
  observer==eater && continue
  get(sight,"capture_us",-1)==now || continue
  any(p->p["ref"]==eater && get(p,"contact",false),sight["peers"]) || continue
  records=get!(()->D(),maps[observer],"observed_food_eating")
  record=get!(()->D("samples"=>0),records,appearance)
  record["samples"]+=1;record["last_us"]=now
 end
end
configured_want_desire(body,gut,stock;kwargs...)=LW.trade_request_desire(body,gut,stock;kwargs...)
function configured_want_interest(body,stock,known,words;security=nothing)
 words===nothing && return nothing
 any(m->m.prediction.appearance=="request-intent",known) || return nothing
 strengths=Float64[]
 for appearance in unique([m.prediction.appearance for m in known])
  kind=appearance==WANT_FISH.appearance ? WANT_FISH.kind :
      startswith(appearance,"request-food-") ? tryparse(Int,replace(appearance,"request-food-"=>"")) : nothing
  kind===nothing && continue
  kind in eachindex(stock) || continue
  stock[kind]>0 || continue
  push!(strengths,log1p(stock[kind])*(1-clamp(LW.trade_food_need(body,nothing,stock;security),0.,1.)))
 end
 isempty(strengths) ? nothing : maximum(strengths)
end
function configured_want_state(ids;fresh=false)
 Dict("listeners"=>Dict(a=>VoiceListener(a;seed=i,vocabulary=a=="npc_e" ? ObservedVocabulary() : configured_want_vocabulary()) for (i,a) in enumerate(ids)),
      "pending"=>Dict{String,Any}(),"last_day"=>Dict{String,Int}(),"records"=>Any[])
end
# 暫定固定: voice experiment only. Known names address a visible partner;
# everyone may hear, but non-addressees do not join this directed request yet.
# Replace explicit address routing with learned pragmatic interpretation later.
function configured_want_addressee!(state,observed,relation,kind,now)
 names=relation===nothing ? D() : get(get(relation,"identity_observation",D()),"names",D())
 peers=filter(p->haskey(names,p),get(observed,"trade_partners",String[]))
 support=LW.item_exchange_supplier_support(state,kind,peers)
 scores=Pair{String,Float64}["broadcast"=>0.]
 append!(scores,[peer=>support[peer] for peer in sort!(collect(keys(support)))])
 loop=get!(() -> LW.BasicLoop(state["actor"]*":request-address";probabilistic=true,seed=state["loop"].seed),state,"request_address_loop")
 choice=voice_select!(loop,scores,"address:$(state["actor"]):$now")
 peer=choice.method=="broadcast" ? nothing : choice.method
 (peer=peer,name=peer===nothing ? nothing : names[peer],support=support,probabilities=choice.probabilities)
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
   body_alive(body) && body.damage<1 && body.strain<1 || continue
   if !(peer in pending["heard"]) && event.start_us<=now<event.start_us+event.duration_us
    mind=voice["listeners"][peer]
    r=voice_listener_step!(w,peer,mind,event;now_us=now,
     response_interest=(known,words)->configured_want_interest(body,foods.personal[peer],known,words;security=food_security(relations[peer])))
    push!(pending["heard"],peer)
    if r.status=="oriented"
     yaw[peer]=mind.yaw
     if r.reply!==nothing && (get(pending,"addressee",nothing)===nothing || pending["addressee"]==peer)
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
   cue=voice_observation(w,reply.peer,caller,reply.event.text;volume=reply.event.volume,attending=true,event_id=reply.event.id)
   cue===nothing && continue
   yaw[caller]=cue.bearing
   memory=get!(()->configured_peer_identity_memory(caller,roster),relations[caller],"identity_observation")
   identity=reply_visual_identity(w,caller,cue,roster,yaw,memory;now)
   configured_want_record!(voice,"recognition",caller,now;peer=reply.peer,status=identity.status)
   if identity.status=="recognized" && pending["identity"]===nothing
    pending["identity"]=identity
    get!(()->Dict{String,Any}(),voice,"supply_requests")[reply.peer]=(partner=caller,kind=pending["requested_food"],expires=event.start_us+CONFIGURED_WANT_VOICE.reply_window_us,call_id=event.id)
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
 supply_requests=get!(()->Dict{String,Any}(),voice,"supply_requests")
 if haskey(supply_requests,actor)
  request=supply_requests[actor]
  if now>=request.expires
   delete!(supply_requests,actor)
  elseif request.partner in get(observed,"trade_partners",String[])
   # Request receipt is an external event: reconsider once now rather than wait
   # beyond its lifetime for the background 64-second poll. Existing busy/trial
   # gates, daily initiation allowance and subjective acceptance stay in force.
   mind=item_social_state!(state);mind["next_us"]=min(mind["next_us"],now)
   selected=deepcopy(observed);filter!(==(request.partner),selected["trade_partners"])
   plan=learned_channel_plan!(state,selected,body,gut,stock,now;allow_start,relation,
       supply_request=(partner=request.partner,kind=request.kind,known_kinds=configured_want_recall(get(kwargs,:map,nothing))),kwargs...)
   configured_want_record!(voice,"supply_considered",actor,now;caller=request.partner,requested_food=request.kind,
       candidates=mind["candidates"],decisions=mind["decisions"],action=plan===nothing ? nothing : plan["action"])
   delete!(supply_requests,actor)
   if plan!==nothing
    plan["request_call_id"]=request.call_id
    configured_want_record!(voice,"proposal",actor,now;target=request.partner,source=plan["source"])
    return plan
   end
  end
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
  word=configured_want_word(voice["listeners"][actor].vocabulary,desire.kind)
  request_word=configured_want_expression(voice["listeners"][actor].vocabulary,"request-intent")
  # No known expression: no catalog fallback and no invented word.
  (word===nothing || request_word===nothing) && return learned_channel_plan!(state,observed,body,gut,stock,now;allow_start,relation,kwargs...)
  voice["last_day"][actor]=day
  # Bound deduplication history to live utterances; completed calls never replay.
  for listener in values(voice["listeners"])
   filter!(p->p.second.event.start_us+CONFIGURED_WANT_VOICE.reply_window_us>now,listener.processed)
  end
  address=configured_want_addressee!(state,observed,relation,desire.kind,now)
  spoken=(address.name===nothing ? "" : address.name*" ")*word*" "*request_word
  event=(id="want:$actor:$now",source=actor,text=spoken,volume=CONFIGURED_WANT_VOICE.volume,start_us=now,duration_us=WANT_FISH.utterance_us)
  voice["pending"][actor]=D("event"=>event,"addressee"=>address.peer,"requested_food"=>desire.kind,"heard"=>Set{String}(),"replies"=>Any[],"delivered"=>Set{String}(),"identity"=>nothing)
  configured_want_record!(voice,"call",actor,now;id=event.id,requested_food=desire.kind,text=event.text,gradient=desire.gradient,addressee=address.peer,supplier_support=address.support,address_probabilities=address.probabilities)
  return D("action"=>"scan","method"=>"voice_request_call","scan_angle"=>CONFIGURED_WANT_VOICE.wait_scan,"configured_rule"=>"voice_request_call")
 end
 learned_channel_plan!(state,observed,body,gut,stock,now;allow_start,relation,kwargs...)
end
