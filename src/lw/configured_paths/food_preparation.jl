# Initial recipe knowledge and temporary body-maintenance routing, not learned MB.
# World recipe/stock accounting remains in world/food_resources.jl.
function configured_food_preparation(r,a,hungry,ingestible,at_home,local_stock;processing_feasible=true,processing_enabled=true)
    hungry || return nothing
    if any(k->RDLBody.food_edible(k) && RDLBody.FOOD_PROCESS_OUTPUT[k]==0,r.inventory[a])
        return ingestible ? "eat" : "rest"
    end
    processing_enabled && food_has_raw(r,a) && at_home && return processing_feasible ? "process_food" : "rest"
    food_has_edible(r,a) && return ingestible ? "eat" : "rest"
    at_home && local_stock>0 && return "retrieve"
    nothing
end
