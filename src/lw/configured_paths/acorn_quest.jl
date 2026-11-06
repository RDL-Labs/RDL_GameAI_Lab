# Training scaffold: objectives and optional tasting lessons; navigation uses the ordinary MB loop.
configured_acorn_quest_state(;tasting=false)=D("stage"=>"learn_home","records"=>Any[],"acquired_sources"=>String[],"delivered"=>0,"arrived"=>false,"returned"=>false,"completed_us"=>nothing,"tasting"=>tasting,"required"=>tasting ? 2 : 1)
function configured_acorn_quest_event!(q,kind,now;kwargs...)
 push!(q["records"],D("kind"=>kind,"us"=>now,(string(k)=>v for (k,v) in kwargs)...))
end
configured_acorn_quest_food_targets(q,visible)=q["stage"] in ("learn_home","outbound") ? filter(f->f["appearance"]=="brown_capped_ovoid",visible) : visible
function configured_acorn_quest_request!(q,learned,now,day_us,at_home,visible)
 if q["stage"]=="learn_home"
  learned && now>=day_us || return nothing
  q["stage"]="outbound";configured_acorn_quest_event!(q,"quest_started",now)
 end
 if q["stage"]=="outbound"
  if !q["arrived"] && any(f->f["appearance"]=="brown_capped_ovoid" && f["distance"]<=1.25,visible)
   q["arrived"]=true;configured_acorn_quest_event!(q,"tree_food_area_reached",now)
  end
  return false
 end
 if q["stage"]=="return" && at_home && !q["returned"]
  q["returned"]=true;configured_acorn_quest_event!(q,"home_reached",now)
 end
 true
end
function configured_acorn_quest_result!(q,action,status,now;kind=0,source=nothing,delivered=String[],liking=nothing)
 if q["stage"]=="outbound" && action=="pickup" && status=="picked_up" && kind==3 && q["arrived"] && source!==nothing
  source in q["acquired_sources"] && return
  push!(q["acquired_sources"],source)
  length(q["acquired_sources"])>=q["required"] && (q["stage"]="return")
  configured_acorn_quest_event!(q,"acorn_acquired",now;source=source)
 elseif q["stage"]=="return" && action=="deposit" && status=="performed"
  count_delivered=count(x->x in q["acquired_sources"],unique(delivered))
  if count_delivered>=q["required"]
   q["delivered"]+=count_delivered;q["stage"]=q["tasting"] ? "taste_raw" : "completed"
   !q["tasting"] && (q["completed_us"]=now)
   configured_acorn_quest_event!(q,"acorn_deposited",now;amount=count_delivered)
  end
 elseif q["stage"]=="taste_raw" && action=="eat" && status=="ate" && kind==3
  q["stage"]="process";configured_acorn_quest_event!(q,"raw_tasted",now;liking)
 elseif q["stage"]=="process" && action=="process_food" && status=="processed"
  q["stage"]="taste_processed";configured_acorn_quest_event!(q,"processing_completed",now)
 elseif q["stage"]=="taste_processed" && action=="eat" && status=="ate" && kind==4
  q["stage"]="taste_fruit"
  configured_acorn_quest_event!(q,"processed_tasted",now;liking)
 elseif q["stage"]=="taste_fruit" && action=="eat" && status=="ate" && kind==1
  q["stage"]="completed";q["completed_us"]=now
  configured_acorn_quest_event!(q,"fruit_tasted",now;liking)
 end
end
function configured_acorn_quest_training_plan(q,inventory,at_home,ingestible,workable)
 stage=q["stage"]
 stage in ("taste_raw","process","taste_processed","taste_fruit") || return nothing
 at_home || return nothing
 kind=stage=="taste_fruit" ? 1 : stage=="taste_processed" ? 4 : 3
 p=D("configured_rule"=>"acorn_training_"*stage,"method"=>"configured_acorn_"*stage)
 if !(kind in inventory)
  return merge(p,D("action"=>"retrieve","food_kind"=>kind))
 end
 action=stage=="process" ? (workable ? "process_food" : "rest") : (ingestible ? "eat" : "rest")
 merge(p,D("action"=>action,"food_kind"=>kind))
end
configured_acorn_quest_finished_plan(q)=q["stage"]=="completed" ? D("action"=>"rest","configured_rule"=>"training_quest_completed","method"=>"configured_acorn_quest_rest") : nothing
configured_acorn_quest_released(q,now,day_us)=q["stage"]=="completed" && now>=(fld(q["completed_us"],day_us)+1)*day_us
