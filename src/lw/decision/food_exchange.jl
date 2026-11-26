# Initial valuation adapter; selection and experience use the common BasicLoop.
# Peer stock is used only through explicit observations; private utility stays hidden.
function observed_food_count(view,other,k)
    stocks=get(view,"observed_food_stocks",nothing)
    stocks!==nothing && haskey(stocks,other) && return get(stocks[other],k,0)
    # A fresh public offer is evidence of the quantity the speaker proposed,
    # never a warehouse inspection. Execution still checks actual ownership.
    announcements=get(view,"announced_food_offers",nothing)
    announcements!==nothing && haskey(announcements,other) && haskey(announcements[other],k) && return announcements[other][k]
    # A proposal reveals its offered quantity, not the owner's full warehouse.
    quantities=[get(o["give_food"],k,0) for o in get(view,"incoming",Any[])
                if get(o,"proposer",nothing)==other && haskey(o,"give_food") && get(o["give_food"],k,0)>0]
    isempty(quantities) ? nothing : maximum(quantities)
end
# Zero candidates is not an observation of zero stock.
observed_food_candidate_count(view,other,k)=something(observed_food_count(view,other,k),0)
"Known food values belong to the observer, including current taste and need."
function food_aid_values(body,gut,kinds;map=nothing,kitchen=nothing)
    weights=food_trade_weights(body,gut;map,kitchen)
    [weights[k]*log1p(1/(1+count(==(k),kinds))) for k in RDLBody.FOOD_KIND_IDS]
end
function food_social_context(body;give_kind=0,want_kind=0,give_count=0,want_count=0)
    context=D("need"=>body_demand(body))
    give_kind>0 && merge!(context,D("give_kind"=>give_kind,"give_count"=>give_count))
    want_kind>0 && merge!(context,D("want_kind"=>want_kind,"want_count"=>want_count))
    context
end
function food_trade_evaluation(body,gut,kind;map=nothing,kitchen=nothing)
    need=body_demand(body)
    best=nothing
    for prepared in (false,true)
        forecast=food_use_forecast(map,kitchen===nothing ? nothing : kitchen.foods,
            kitchen===nothing ? nothing : kitchen.actor,kind,prepared,gut,body_energy(body),
            kitchen===nothing ? () : kitchen.facilities,kitchen===nothing ? (0.,0.) : kitchen.position;
            processing=kitchen!==nothing && kitchen.processing)
        forecast===nothing && continue
        nutrition=food_nutrient_trade_evidence(map,gut,forecast.output)
        base=.2+.6need+food_taste_value(forecast.liking,body_energy(body),gut)-forecast.cost
        value=base+nutrition.utility
        if best===nothing || value>best.value
            best=(;value,base,output=forecast.output,nutrition)
        end
    end
    aversion=food_condition_aversion(map,kind)
    best===nothing ? (value=-aversion,base=-aversion,output=0,nutrition=nothing) :
        merge(best,(value=best.value-aversion,base=best.base-aversion))
end
food_trade_weight(body,gut,kind;map=nothing,kitchen=nothing)=food_trade_evaluation(body,gut,kind;map,kitchen).value
food_trade_weights(body,gut;map=nothing,kitchen=nothing) =
    [food_trade_weight(body,gut,kind;map,kitchen) for kind in RDLBody.FOOD_KIND_IDS]

# Compatibility definitions only. Normal LW never creates/updates this controller.
include(joinpath(@__DIR__, "../configured_paths/legacy_food_trade.jl"))
