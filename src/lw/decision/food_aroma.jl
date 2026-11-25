# Authored sensory approximation, not nutrient analysis or atmospheric diffusion.
# world emission stays in observation_states; owner memories only receive features.
const FOOD_AROMA_RULE=(distance_scale=4.,match_scale=.25,cooking=1.,ready=.7,eating=.6,
    tail_us=60_000_000,recall_gain=.35,history_limit=64)
# sweet/roasted/fatty-like abstract channels. No edible/safe flags reach observers.
const FOOD_AROMA_FEATURES=((.8,.1,.1),(.4,0.,0.),(.1,.1,.1),(.2,.7,.2),
    (.1,0.,.4),(0.,.1,.8),(.1,.9,.7),(.1,.9,.7))
food_aroma_feature(kind)=FOOD_AROMA_FEATURES[kind]
function food_aroma_strength(emission,now)
 emission===nothing && return 0.
 elapsed=max(0,now-emission["us"])
 emission["phase"]=="ready" ? emission["strength"] : emission["strength"]*max(0.,1-elapsed/FOOD_AROMA_RULE.tail_us)
end
function food_aroma_update!(observer_state,map,action,status,kind,inventory,now)
 emission=get(observer_state,"world_food_aroma",nothing)
 phase=action=="process_food" && status=="processing" ? "cooking" :
       action=="process_food" && status=="processed" ? "ready" :
       action=="eat" && status=="ate" ? "eating" : nothing
 if phase!==nothing && kind>0
  strength=getproperty(FOOD_AROMA_RULE,Symbol(phase))
  observer_state["world_food_aroma"]=D("kind"=>kind,"features"=>food_aroma_feature(kind),"strength"=>strength,"phase"=>phase,"us"=>now)
  stats=get!(() -> D(),map,"food_aroma_stats");stats[phase]=get(stats,phase,0)+1
 elseif emission!==nothing && emission["phase"]!="tail"
  emission["phase"]=="ready" && emission["kind"] in inventory && return
  emission["phase"]="tail";emission["us"]=now
 end
end
function food_aroma_snapshot(states,positions,inventory,now)
 rows=Any[]
 for actor in IDS
  emission=get(states[actor],"world_food_aroma",nothing)
  if emission!==nothing && emission["phase"]=="ready" && !(emission["kind"] in inventory[actor])
   emission["phase"]="tail";emission["us"]=now
  end
  strength=food_aroma_strength(emission,now)
  strength>0 || continue
  push!(rows,(actor=actor,position=positions[actor],features=emission["features"],strength=strength))
 end
 rows
end
function food_aroma_learn!(map,kind,quality)
 # Only invoked after the actor's actual meal, alongside the taste sample.
 entry=map["food_taste_experiences"][food_taste_key(kind,quality)]
 entry["aroma_features"]=food_aroma_feature(kind)
end
function food_aroma_observe!(map,actor,position,rows,now)
 active=D();detected=0
 for cue in rows
  cue.actor==actor && continue
  distance=hypot(position[1]-cue.position[1],position[2]-cue.position[2])
  strength=cue.strength/(1+(distance/FOOD_AROMA_RULE.distance_scale)^2)
  detected+=1
  for (key,memory) in get(map,"food_taste_experiences",D())
   haskey(memory,"aroma_features") && get(memory,"samples",0)>0 || continue
   fit=exp(-sum((x-y)^2 for (x,y) in zip(cue.features,memory["aroma_features"]))/FOOD_AROMA_RULE.match_scale)
   activation=strength*fit
   active[key]=max(get(active,key,0.),activation)
  end
 end
 sensory=get!(() -> D("observed_ticks"=>0,"recall_ticks"=>0,"active"=>D(),"records"=>Any[]),map,"food_aroma")
 sensory["active"]=active;sensory["us"]=now
 detected>0 && (sensory["observed_ticks"]+=1)
 !isempty(active) && (sensory["recall_ticks"]+=1)
 # Bounded diagnostics; decision uses current activation, not these samples.
 if detected>0 && (isempty(sensory["records"]) || now-last(sensory["records"])["us"]>=FOOD_AROMA_RULE.tail_us)
  push!(sensory["records"],D("us"=>now,"sources"=>detected,"active"=>copy(active)))
  length(sensory["records"])>FOOD_AROMA_RULE.history_limit && popfirst!(sensory["records"])
 end
end
function food_aroma_bonus(map,kind,quality,liking)
 sensory=get(map,"food_aroma",nothing);sensory===nothing && return 0.
 FOOD_AROMA_RULE.recall_gain*get(sensory["active"],food_taste_key(kind,quality),0.)*liking
end
