# Food alternatives use the common transition field and H-dependent distribution.
# Recipe availability is initial knowledge; taste is updated from experienced meals.
food_desire_state()=D("intent"=>nothing,"next_us"=>0,"records"=>Any[])
function food_desire_record!(state,row)
 push!(state["records"],row);length(state["records"])>64 && popfirst!(state["records"])
end
function food_remember_taste!(map,kind,quality,liking,now)
 experiences=get!(map,"food_taste_experiences",D())
 entry=get!(() -> D("samples"=>0,"liking_sum"=>0.),experiences,food_taste_key(kind,quality))
 entry["samples"]+=1
 entry["liking_sum"]+=liking
 entry["mean_liking"]=entry["liking_sum"]/entry["samples"]
 entry["composition"]=RDLBody.FOOD_COMPOSITION[kind]
 entry["last_us"]=now
end
function food_expected_taste(map,kind,gut,reserve;quality=2)
 experiences=map===nothing ? nothing : get(map,"food_taste_experiences",nothing)
 experience=experiences===nothing ? nothing : get(experiences,food_taste_key(kind,quality),nothing)
 # Expected pleasure is remembered experience, not a preview of the body's
 # current sensory result. Nutrient demand/fullness act when eating instead.
 experience!==nothing && haskey(experience,"mean_liking") && return experience["mean_liking"]
 base=RDLBody.food_base_taste(gut,kind)+game_food_bonus(kind,quality)
 # Older fixtures can supply a baseline without any observed meal.
 if experience!==nothing && !haskey(experience,"mean_liking")
  base=get(experience,"base_liking",base)
 end
 # Unexperienced foods retain a scenario prior. It is replaced by tasting,
 # and does not expose current nutrient stores or satiety to prediction.
 return base
end
# Decision weight only. The sensory experience stored after eating stays in taste units.
food_taste_value(liking,reserve)=liking*(1+2clamp(reserve/100,0.,1.))

# Same local recipe forecast for an owned ingredient and a proposed ingredient.
function recognized_salt(map,row)
 map===nothing && return false
 key="$(row["color"]):$(row["size"]):$(row["light_source"])"
 get(get(map,"salt_appearance_samples",D()),key,false) && return true
 sample=get(get(map,"item_taste_experiences",D()),key,nothing)
 sample!==nothing && sample["salinity"]>0
end
function owned_cooking_salt(items,map,actor,at_home)
 items===nothing && return nothing
 for id in items["initial_ids"]
  item=items["items"][id]
  if item["owner"]==actor && (item["location"]==ITEM_HELD || at_home && item["location"]==ITEM_STORED) && recognized_salt(map,item)
   return id
  end
 end
 nothing
end
function food_use_forecast(map,foods,actor,kind,prepared,gut,reserve,facilities,position;
                           processing=true,held=false,source_quality=2,salted=false)
 output=prepared ? RDLBody.FOOD_PROCESS_OUTPUT[kind] : kind
 if salted
  prepared && kind==RDLBody.FISH_FOOD || return nothing
  output=RDLBody.SALTED_FISH
 end
 output!=0 && RDLBody.food_edible(output) || return nothing
 prepared && (!processing || food_facility_for(facilities,position,kind)===nothing) && return nothing
 ticks=(held ? 0 : 1)+(prepared ? RDLBody.FOOD_PROCESS_TICKS[kind] : 0)+1
 cost=ticks/1800.0*(1+max(0.,(100-reserve)/20.))
 skill=prepared && hasproperty(foods,:game) ? food_skill_forecast(foods,actor,kind) : nothing
 quality=prepared ? (skill===nothing ? 2 : skill.quality) : source_quality
 liking=food_expected_taste(map,output,gut,reserve;quality)
 (;output,cost,skill,quality,liking)
end
function food_desire_candidates(map,foods,a,gut,reserve,at_home,stores,facilities,position;processing=true,items=nothing)
 candidates=Any[];pressure=haskey(map,"hunger_forecast") ? hunger_pressure(reserve) : max(0.,(100-reserve)/20.)
 for kind in RDLBody.FOOD_KIND_IDS, source_quality in 1:4
  held=food_held_quality(foods,a,kind,source_quality)
  held || (at_home && food_stored_quality_count(foods,a,stores,kind,source_quality)>0) || continue
  aversion=food_condition_aversion(map,kind)
  if aversion>0 && food_disposal_for(facilities,position)!==nothing
   field=relational_transition(0.,aversion;cost=1/1800.)
   push!(candidates,D("method"=>"discard:$kind:q$source_quality","priority"=>field.expected,
    "raw_kind"=>kind,"food_kind"=>kind,"source_quality"=>source_quality,"quality"=>source_quality,
    "prepare"=>false,"discard"=>true,"expected_relief"=>aversion))
  end
  if !RDLBody.food_edible(kind) && RDLBody.FOOD_PROCESS_OUTPUT[kind]==0
   # Unfamiliar material can be checked; the rejection is learned, not hidden
   # by the world's edibility gate before the observer has tried it.
   usable=food_condition_usable(map,kind)
   field=relational_transition(0.,4usable - 3.0 - food_condition_aversion(map,kind);cost=(held ? 1 : 2)/1800.)
   push!(candidates,D("method"=>"inspect:$kind","priority"=>field.expected,
    "raw_kind"=>kind,"food_kind"=>kind,"prepare"=>false,"inspect"=>true,
    "source_quality"=>source_quality,"quality"=>source_quality,"expected_usable"=>usable))
   continue
  end
  salt_id=kind==RDLBody.FISH_FOOD ? owned_cooking_salt(items,map,a,at_home) : nothing
  for recipe in 0:(salt_id===nothing ? 1 : 2)
   prepared=recipe>0; salted=recipe==2
   forecast=food_use_forecast(map,foods,a,kind,prepared,gut,reserve,facilities,position;processing,held,source_quality,salted)
   forecast===nothing && continue
   (;output,cost,skill,quality,liking)=forecast
   field=relational_transition(0.,pressure+food_taste_value(liking,reserve);cost)
   clock=get(map,"food_clock",(now=0,day_us=17_280_000_000))
   urgency=mod(clock.now,clock.day_us)/clock.day_us
   # Choosing this meal uses a limited eating opportunity before its expected loss.
   loss_risk=1-food_storage_survival(map,kind,1)
   usable_before_deadline=(!prepared || RDLBody.FOOD_PROCESS_TICKS[kind]<(clock.day_us-mod(clock.now,clock.day_us))/1e6)
   loss_relief=usable_before_deadline ? loss_risk*(.5+1.5urgency)*(1+max(0.,liking)) : 0.
   method="meal:$(kind):$(prepared)"*(source_quality==2 ? "" : ":q$source_quality")
   salted && (method*=":salt")
   push!(candidates,D("salt_id"=>salted ? salt_id : nothing,"method"=>method,"priority"=>field.expected+loss_relief,"expiry_relief"=>loss_relief,"loss_risk"=>loss_risk,
    "raw_kind"=>kind,"food_kind"=>output,"prepare"=>prepared,"expected_liking"=>liking,"cost"=>cost,
    "source_quality"=>source_quality,"quality"=>quality,"skill_forecast"=>skill))
  end
 end
 # Compare only meals the actor can actually obtain here. The existing scores
 # already include waiting/work cost. More reserve allows greater selectivity.
 meals=filter(c->haskey(c,"expected_liking"),candidates)
 if !isempty(meals)
  best=maximum(c["priority"] for c in meals)
  for meal in meals
   disadvantage=max(0.,best-meal["priority"])
   aversion=max(0.,-meal["expected_liking"])
   penalty=4.0*clamp(reserve/100,0.,1.)*aversion*disadvantage
   meal["alternative_penalty"]=penalty
   meal["priority"]-=penalty
  end
 end
 push!(candidates,D("method"=>"meal:defer","priority"=>0.,"defer"=>true))
 candidates
end
function food_desire_plan!(map,loop,foods,a,gut,body,at_home,stores,facilities,position,now;requested=false,processing=true,items=nothing)
 state=get!(food_desire_state,map,"food_desire")
 intent=state["intent"]
 if intent===nothing
  now>=state["next_us"] || return nothing
  if !requested && !(food_disposal_for(facilities,position)!==nothing &&
      any(k->food_condition_aversion(map,k)>0 && (k in foods.inventory[a] || at_home && stores[k]>0),RDLBody.FOOD_KIND_IDS))
   return nothing
  end
  candidates=food_desire_candidates(map,foods,a,gut,body.reserve,at_home,stores,facilities,position;processing,items)
  if !requested || gut!==nothing && !can_ingest(gut)
   filter!(c->get(c,"discard",false) || get(c,"defer",false),candidates)
  end
  length(candidates)>1 || return nothing
  probabilities=method_distribution(loop,candidates);u=rand(loop.rng);index=length(candidates);acc=0.
  for i in eachindex(candidates);acc+=probabilities[i];if u<acc;index=i;break;end;end
  selected=candidates[index]
  food_desire_record!(state,D("us"=>now,"kind"=>"choice","selected"=>selected["method"],"candidates"=>deepcopy(candidates),"probabilities"=>probabilities))
  if get(selected,"defer",false)
   state["next_us"]=now+64_000_000
   return nothing
  end
  intent=copy(selected);state["intent"]=intent
 end
 raw=intent["raw_kind"];output=intent["food_kind"]
 quality=get(intent,"quality",2);source_quality=get(intent,"source_quality",2)
 if get(intent,"discard",false)
  return D("action"=>"discard_food","food_kind"=>raw,"food_quality"=>source_quality,"method"=>intent["method"],"food_desire"=>true)
 end
 if food_held_quality(foods,a,output,quality)
  action=get(intent,"inspect",false) ? "inspect_food" : gut===nothing || can_ingest(gut) ? "eat" : "rest"
  return D("action"=>action,"food_kind"=>output,"food_quality"=>quality,"method"=>intent["method"],"food_desire"=>true)
 end
 salt_id=get(intent,"salt_id",nothing)
 salt_ready=salt_id===nothing || owned_cooking_salt(items,map,a,at_home)==salt_id
 if raw in foods.inventory[a] && salt_ready && intent["prepare"] && processing && food_facility_for(facilities,position,raw)!==nothing
  action=step(body,"process_food",length(foods.inventory[a]))[2]=="worked" ? "process_food" : "rest"
  return D("action"=>action,"food_kind"=>raw,"salt_id"=>salt_id,"method"=>intent["method"],"food_desire"=>true)
 end
 if !food_held_quality(foods,a,raw,source_quality) && at_home && food_stored_quality_count(foods,a,stores,raw,source_quality)>0
  return D("action"=>"retrieve","food_kind"=>raw,"food_quality"=>source_quality,"method"=>intent["method"],"food_desire"=>true)
 end
 food_desire_record!(state,D("us"=>now,"kind"=>"unavailable","selected"=>intent["method"]))
 state["intent"]=nothing;state["next_us"]=now+1_000_000
 nothing
end
function food_desire_result!(map,plan,status,kind,liking,now)
 state=get(map,"food_desire",nothing)
 state===nothing && return
 if get(plan,"action",nothing)=="discard_food"
  food_desire_record!(state,D("us"=>now,"kind"=>"disposal","status"=>status,"intent"=>state["intent"]))
  state["intent"]=nothing;state["next_us"]=now+(status=="discarded" ? 1_000_000 : 64_000_000)
 elseif status in ("food_rejected","food_usable")
  food_desire_record!(state,D("us"=>now,"kind"=>"condition_checked","status"=>status,"intent"=>state["intent"]))
  state["intent"]=nothing;state["next_us"]=now+64_000_000
 elseif status=="ate"
  if haskey(map,"hunger_forecast")
   h=map["hunger_forecast"];h["forecast"]=nothing;h["H"]=0.
   # Ingestion resolves the meal attempt; digestion/body recovery remains gradual.
  end
  food_desire_record!(state,D("us"=>now,"kind"=>"meal","food_kind"=>kind,"liking"=>liking,"intent"=>state["intent"]))
  state["intent"]=nothing;state["next_us"]=now+1_000_000
 elseif get(plan,"food_desire",false) && status in ("unavailable","preparation_unavailable","no_ingredient","no_edible_food")
  food_desire_record!(state,D("us"=>now,"kind"=>"failed","status"=>status))
  state["intent"]=nothing;state["next_us"]=now+1_000_000
 end
end
