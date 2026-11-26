# Recall starts in owner memory. Registry lookup decodes an appearance, not a
# catalog of desires or another actor's inventory.
function trade_request_recall(map)
    map===nothing && return Int[]
    recalled=Int[]
    for group in ("food_taste_experiences","observed_food_eating"), (key,record) in get(map,group,D())
        get(record,"samples",0)>0 || continue
        kind=findfirst(==(first(split(key,":quality:"))),RDLBody.FOOD_APPEARANCE)
        kind===nothing || push!(recalled,kind)
    end
    sort!(unique!(recalled))
end
function trade_request_desire(body,gut,stock;map=nothing,kitchen=nothing,relation=nothing)
    stock===nothing && return nothing
    security=map===nothing ? food_security(relation) : get(map,"food_security",food_security(relation))
    valuation=trade_valuation_context(body,gut,security,D(),nothing)
    candidates=Any[]
    for kind in trade_request_recall(map)
        weight=food_trade_weight(body,gut,kind;map,kitchen)
        weight>0 || continue
        after=copy(stock);after[kind]+=1
        gradient=trade_compound_gradient(stock,after,weight*(log1p(after[kind])-log1p(stock[kind])),valuation)
        gradient["total"]>0 && push!(candidates,(kind=kind,gradient=gradient))
    end
    isempty(candidates) ? nothing : candidates[argmax([c.gradient["total"] for c in candidates])]
end
