# Initial food-security adapter shared by food-only and mixed barter.
# Owned processable food and gut contents can satisfy the near-term requirement.
function trade_food_need(body,gut,stock;security=nothing)
    stock===nothing && return 0.
    required=max(1.,(80.0-body.reserve)/RDLBody.MEAL_ENERGY,security===nothing ? 0. : security["required"])
    digesting=gut===nothing ? 0. : gut.gut
    supplied=sum((stock[k]*(security===nothing || RDLBody.food_edible(k) ? 1. : .65) for k in eachindex(stock) if RDLBody.food_edible(k) || RDLBody.FOOD_PROCESS_OUTPUT[k]!=0);init=0.)
    max(0.,required-digesting-supplied)
end

# Initial coefficients, shared by both negotiation channels. Freeze the owner's
# forecast and observed expression at choice; never inspect the partner's body.
function trade_valuation_context(body,gut,security,situation,trace;food_enabled=true)
    profile=trace===nothing ? D() : trace["profile"]
    benefit=get(profile,"benefit",0.);credit=get(profile,"aid_credit",0.);familiar=get(profile,"familiarity",0.)
    D("required"=>food_enabled ? max(1.,(80-body.reserve)/RDLBody.MEAL_ENERGY,security===nothing ? 0. : security["required"]) : 0.,
        "digesting"=>gut===nothing ? 0. : gut.gut,
        "food_units"=>[RDLBody.food_edible(k) ? 1. : RDLBody.FOOD_PROCESS_OUTPUT[k]!=0 ? (security===nothing ? 1. : .65) : 0. for k in RDLBody.FOOD_KIND_IDS],
        "distress"=>clamp(get(situation,"distress",0.),0.,1.),"fear"=>clamp(get(situation,"fear",0.),0.,1.),
        "affiliation"=>clamp(1+.75credit+.5benefit+.1familiar,0.,2.5),
        "relationship"=>.05benefit+.1credit+.02familiar)
end

function trade_compound_gradient(before,after,material,valuation;cost=.002)
    units=valuation["food_units"]
    supplied(x)=x===nothing ? 0. : sum(units[k]*x[k] for k in eachindex(units))
    deficit(x)=max(0.,valuation["required"]-valuation["digesting"]-supplied(x))
    initial=deficit(before);final=deficit(after)
    security=.5*((1+initial)^2-(1+final)^2)
    delivered=max(0.,supplied(before)-supplied(after))
    # A prediction of helping, not proof that the recipient recovered. Fear can
    # make food a weaker response to the visible distress. No return promise.
    aid=valuation["distress"]*(1-.5valuation["fear"])*valuation["affiliation"]*log1p(delivered)
    relationship=valuation["relationship"]
    D("material"=>material,"security"=>security,"aid"=>aid,"relationship"=>relationship,
        "cost"=>-cost,"total"=>material+security+aid+relationship-cost,
        "need_before"=>initial,"need_after"=>final)
end

function trade_food_relief(body,gut,stock,give,want;security=nothing)
    stock===nothing && return 0.
    all(stock.>=give) || return 0.
    trade_food_need(body,gut,stock;security)-trade_food_need(body,gut,stock.-give.+want;security)
end
