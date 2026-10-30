# Initial food-security adapter shared by food-only and mixed barter.
# Owned processable food and gut contents can satisfy the near-term requirement.
function trade_food_need(body,gut,stock)
    stock===nothing && return 0.
    required=max(1.,(80.0-body.reserve)/RDLBody.MEAL_ENERGY)
    digesting=gut===nothing ? 0. : gut.gut
    supplied=sum((stock[k] for k in eachindex(stock) if RDLBody.food_edible(k) || RDLBody.FOOD_PROCESS_OUTPUT[k]!=0);init=0)
    max(0.,required-digesting-supplied)
end

function trade_food_relief(body,gut,stock,give,want)
    stock===nothing && return 0.
    all(stock.>=give) || return 0.
    trade_food_need(body,gut,stock)-trade_food_need(body,gut,stock.-give.+want)
end
