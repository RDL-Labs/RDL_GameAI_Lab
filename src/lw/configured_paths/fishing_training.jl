# Explicit teaching scaffold, not an autonomous fishing preference.
configured_fishing_training_state(;salt=false,visual=false)=D("stage"=>"taste","records"=>Any[],"salt"=>salt,"visual"=>visual)
configured_fishing_training_active(q)=q["stage"]!="completed"
function configured_fishing_training_plan(q,inventory,at_home,ingestible,visible;items=nothing,actor=nothing)
    stage=q["stage"]
    visual=get(q,"visual",false)
    if visual && stage=="taste" && at_home
        action=RDLBody.SALTED_FISH in inventory ? (ingestible ? "eat" : "rest") : "retrieve"
        return D("action"=>action,"food_kind"=>RDLBody.SALTED_FISH,"method"=>"salted_fish_sample","configured_rule"=>"fishing_training_taste")
    elseif visual && stage=="salt" && at_home
        return D("action"=>"observe_salt_sample","method"=>"salt_appearance","configured_rule"=>"fishing_training_visual")
    elseif stage=="taste" && at_home
        cooked=RDLBody.COOKED_FISH in inventory
        return D("action"=>cooked ? (ingestible ? "eat" : "rest") : RDLBody.FISH_FOOD in inventory ? "process_food" : "retrieve",
            "food_kind"=>cooked ? RDLBody.COOKED_FISH : RDLBody.FISH_FOOD,"method"=>"configured_fishing_taste","configured_rule"=>"fishing_training_taste")
    elseif stage=="salt" && at_home
        sample=configured_salt_sample(items,actor)
        sample===nothing && return D("action"=>"rest","configured_rule"=>"salt_sample_unavailable")
        return D("action"=>"taste_item","item_id"=>sample["id"],"method"=>"configured_salt_taste","configured_rule"=>"fishing_training_salt")
    elseif stage=="trial"
        target=findfirst(v->get(v,"acquisition","")=="fishing" && v["distance"]<=1.25,visible)
        target===nothing && return nothing
        return D("action"=>"fish","food_ref"=>visible[target]["ref"],
            "method"=>"configured_fishing_trial","configured_rule"=>"fishing_training_trial")
    end
    nothing
end
function configured_fishing_training_result!(q,action,status,kind,at_home,now;liking=nothing)
    stage=q["stage"]
    if stage=="taste" && action=="eat" && status=="ate" && kind==(get(q,"visual",false) ? RDLBody.SALTED_FISH : RDLBody.COOKED_FISH)
        q["stage"]=(get(q,"salt",false) || get(q,"visual",false)) ? "salt" : "trial"
        push!(q["records"],D("kind"=>(get(q,"visual",false) ? "salted_fish_tasted" : "fish_tasted"),"us"=>now,"liking"=>liking))

    elseif stage=="salt" && action=="observe_salt_sample" && status=="observed"
        q["stage"]="trial"
        push!(q["records"],D("kind"=>"salt_appearance_observed","us"=>now))
    elseif stage=="salt" && action=="taste_item" && status=="tasted"
        q["stage"]="trial"
        push!(q["records"],D("kind"=>"salt_tasted","us"=>now))
    elseif stage=="trial" && action=="fish" && status in ("picked_up","no_catch")
        q["stage"]="return"
        push!(q["records"],D("kind"=>"attempt_completed","us"=>now,"caught"=>status=="picked_up"))
    elseif stage=="return" && at_home
        q["stage"]="completed"
        push!(q["records"],D("kind"=>"training_completed","us"=>now))
    end
end

configured_fishing_training_returning(q)=q["stage"]!="trial"
configured_fishing_training_targets(visible)=filter(v->get(v,"acquisition","")=="fishing",visible)

function configured_salt_sample(items,a)
    items===nothing && return nothing
    for id in items["initial_ids"]
        item=items["items"][id]
        item["kind"]==ROCK_SALT_ITEM && item["owner"]==a && item["location"] in (ITEM_HELD,ITEM_STORED) && return item
    end
    nothing
end
# Fixed teaching display uses the registered appearance without granting an item.
function configured_observe_salt_sample!(map,items)
 sample=items["registry"][ROCK_SALT_ITEM]
 key="$(sample["color"]):$(sample["size"]):$(sample["light_source"])"
 get!(D,map,"salt_appearance_samples")[key]=true
 "observed"
end
