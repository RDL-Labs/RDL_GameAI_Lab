# Modify only a new experiment's frozen source, never ordinary LW's independent curricula.
function api_field_training_input!(input)
    scene=input["scene"]
    for key in ("configured_acorn_quest","configured_acorn_tasting","configured_quest_release",
                "configured_camp_landmark","configured_camp_experience","configured_camp_exterior",
                "configured_fishing_training")
        scene[key]=true
    end
    scene["configured_tasting_training"]=false
    scene["configured_salted_fish_sample"]=false
    scene["configured_salt_tasting"]=false
    scene["personal_food_supply"]=nothing
    scene["post_return_idle"]=false
    scene["post_return_meal"]=false
    scene["food_security_provision"]=false
    input["config"]["home_observation"]="on"
    input["config"]["daily_delivery"]="on"
end
function api_field_training_instrument(text)
    replace_once(from,to)=begin
        @assert length(findall(from,text))==1 from
        text=replace(text,from=>to)
    end
    replace_once("fishing_enabled && !acorn_quest && !shared_stores","fishing_enabled && !shared_stores")
    replace_once("check(foods!==nothing && (sample_kind in foods.inventory[a] || foods.personal[a][sample_kind]>=1),\"fishing_training_requires_initial_tasting_sample\")",
                 "check(foods!==nothing,\"field_training_requires_food_state\")")
    anchor="mb_maps[a][\"fishing_training\"]=configured_fishing_training_state(;salt=salt_training,visual=visual_training)"
    replace_once(anchor,anchor*";mb_maps[a][\"fishing_training\"][\"stage\"]=\"waiting_acorn\"")
    text=replace(text,"configured_fishing_training_active("=>"configured_api_fish_active(")
    replace_once("            day>=3 && (personal_supply=nothing)",
                 "            personal_supply=configured_api_training_supply!(mb_maps,day,now,clock.day_us)")
    anchor="            food_targets=acorn_quest ?"
    replace_once(anchor,"            configured_api_training_observe!(a,mb_maps[a],now;observed=landmarks===nothing ? nothing : landmarks[a],heading=yaw[a])\n"*anchor)
    text
end
