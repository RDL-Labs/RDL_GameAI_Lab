# Initial recipe knowledge and temporary body-maintenance routing, not learned MB.
# World recipe/stock accounting remains in world/food_resources.jl.
function configured_food_preparation(r,a,hungry,ingestible,at_home,local_stock;processing_feasible=true)
    hungry || return nothing
    if food_has_edible(r,a)
        return ingestible ? "eat" : "rest"
    end
    food_has_raw(r,a) && at_home && return processing_feasible ? "process_food" : "rest"
    at_home && local_stock>0 && return "retrieve"
    nothing
end
