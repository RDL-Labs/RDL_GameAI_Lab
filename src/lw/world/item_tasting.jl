# A small taste of an owned salt crystal, not a meal or processing recipe.
# The crystal remains transferable; sub-gram depletion is outside this model.
function item_taste!(items,map,w,home,a,id,now)
    items===nothing && return "taste_unavailable"
    item=get(items["items"],id,nothing)
    item===nothing && return "taste_unavailable"
    item["kind"]==ROCK_SALT_ITEM && item["owner"]==a &&
        (item["location"]==ITEM_HELD || item["location"]==ITEM_STORED && item_at_home(w,home,a)) || return "taste_unavailable"
    features=item_descriptor(item)
    experiences=get!(() -> D(),map,"item_taste_experiences")
    key="$(features["color"]):$(features["size"]):$(features["light_source"])"
    entry=get!(() -> D("features"=>features,"samples"=>0,"salinity"=>0.,"last_us"=>-1),experiences,key)
    entry["last_us"]==now && return "tasted"
    entry["samples"]+=1;entry["salinity"]=GAME_SALT_SAMPLE_SALINITY;entry["last_us"]=now
    "tasted"
end
