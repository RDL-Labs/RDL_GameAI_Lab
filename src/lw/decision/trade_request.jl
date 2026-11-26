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

# Owner-local recipe knowledge and reachable facilities, shared with food desire.
# Output taste must have been experienced/observed; the recipe itself is existing
# initial knowledge, not a recipe learned by this request adapter.
function trade_request_processing(map,body,gut,kitchen,input,output;items=nothing)
    kitchen===nothing && return nothing
    recalled=trade_request_recall(map)
    input in recalled && output in recalled && input!=output || return nothing
    step(body,"process_food",length(kitchen.foods.inventory[kitchen.actor]))[2]=="worked" || return nothing
    salted=output==RDLBody.SALTED_FISH
    salt_id=salted ? owned_cooking_salt(items,map,kitchen.actor,true) : nothing
    salted && salt_id===nothing && return nothing
    forecast=food_use_forecast(map,kitchen.foods,kitchen.actor,input,true,gut,body_energy(body),kitchen.facilities,kitchen.position;
        processing=kitchen.processing,salted)
    forecast===nothing && return nothing
    forecast.output==output || return nothing
    D("input"=>input,"output"=>output,"cost"=>forecast.cost,"quality"=>forecast.quality,
        "ticks"=>RDLBody.FOOD_PROCESS_TICKS[input]+2,"salt_id"=>salt_id)
end
function trade_request_processing_inputs(map,body,gut,kitchen,output;items=nothing)
    inputs=Dict{Int,Any}()
    for input in trade_request_recall(map)
        forecast=trade_request_processing(map,body,gut,kitchen,input,output;items)
        # Publish the claimed transformation, not private salt/item references.
        forecast===nothing || (inputs[input]=D("input"=>input,"output"=>output))
    end
    inputs
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
