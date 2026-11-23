using SHA
# Port of runtime/refusal_relation_field.py's respond path (affiliation=0).
function experienced_response(obs,records,pressure,owner,seed;retention=0.,relation=nothing,now=nothing,available_food=obs["inventory"]>0)
    check(obs["self_id"]==owner && pressure.parent.goal_id==owner*":obtain-aid","response_owner")
    m=first(obs["messages"]);other=m["sender"]
    if m["kind"]!="request" || !any(x->x["ref"]==other,obs["others"])
        return response(obs,true),nothing
    end
    sources=String[];weight=0.
    # Receiving aid and deciding to provide it are different questions. Keep
    # request H intact; neither its temperature nor legacy refusal H belongs
    # to this response. Relationship experience still enters through the MB.
    relation!==nothing && check(relation["actor"]==owner,"response_relation_owner")
    unified=hasproperty(pressure,:loop)
    response_loop=unified ? BasicLoop(owner*":provide-aid";probabilistic=true) : nothing
    situation=social_observed_context(relation,other,D("need"=>body_observed_demand(obs["body"])))
    relationship=relation===nothing ? nothing : unified ?
        social_relation_bias(relation,other,"give";situation,H=0.) :
        social_relation_bias(relation,other,"give")
    relationship!==nothing && (relationship["applies_to"]="give")
    reserve=body_observed_energy(obs["body"]);need=2body_observed_demand(obs["body"])
    score=1.0 - need - weight - retention - food_anxiety(food_security(relation)) + get(situation,"distress",0.) + (relationship===nothing ? 0. : relationship["weight"])
    probability=if !available_food
        0.
    elseif unified
        method_distribution(response_loop,Any[
            D("method"=>"refuse:"*other,"priority"=>0.),
            D("method"=>"give:"*other,"priority"=>score)])[2]
    else
        exp(score)/(1+exp(score))
    end
    digest=sha256(seed);bits=foldl((x,b)->(x<<8)|UInt64(b),digest[1:8];init=UInt64(0))
    draw=Float64(bits)/18446744073709551616.0
    action=draw<1-probability ? "refuse" : "give"
    components=D("baseline"=>1.,"own_need"=>-need,"prior_refusal"=>-weight,"retention"=>-retention,
        "anxiety"=>-food_anxiety(food_security(relation)),"appearance"=>get(situation,"distress",0.),
        "relation"=>relationship===nothing ? 0. : relationship["weight"])
    candidates=Any[D("method"=>"refuse:"*other,"action"=>"refuse","priority"=>0.),
        D("method"=>"give:"*other,"action"=>"give","priority"=>score,"context"=>situation,
          "components"=>components,"gradient_relation"=>relationship,"feasible"=>available_food)]
    selected=action=="give" ? candidates[2] : candidates[1]
    gradient_capture!(relation,response_loop,candidates,selected,seed,now;
        channel="aid_response",probabilities=[1-probability,probability])
    trace=D("source"=>seed,"other"=>other,"weight"=>weight,"sources"=>sources,
        "need"=>need,"retention_cost"=>retention,"give_probability"=>probability,"draw"=>draw,"selected"=>action,
        "authority"=>"local response use rule; not inferred intent")
    trace["pressure_scope"]="provide-aid-current-evaluation"
    trace["response_H"]=0.
    unified && (trace["selection"]="common_H_distribution")
    relationship!==nothing && (trace["relationship"]=relationship)
    (action,other,m["id"]),trace
end

# Fulfil an already chosen response with normal retrieve/give actions. No gift
# is forced: the response was selected by the common loop; loss of contact,
# deadline or the promised edible resource cancels this short execution plan.
function aid_response_food(kinds,stock,at_home)
    !isempty(kinds) && return RDLBody.food_edible(first(kinds)) ? Int(first(kinds)) : 0
    (!at_home || stock===nothing) && return 0
    something(findfirst(k->stock[k]>0 && RDLBody.food_edible(k),eachindex(stock)),0)
end
function aid_response_continue!(relation,kinds,contacts,now)
    relation===nothing && return nothing
    pending=pop!(relation,"aid_delivery",nothing);pending===nothing && return nothing
    now>=pending["deadline_us"] && return nothing
    any(peer->peer["ref"]==pending["target"],contacts) || return nothing
    if isempty(kinds) || first(kinds)!=pending["food_kind"] || !RDLBody.food_edible(first(kinds))
        return merge(pending,D("action"=>"refuse"))
    end
    merge(pending,D("action"=>"give"))
end


# The request_again path of refusal_relation_field.choose. A withheld request
# returns authority to the existing activity; it is not a forced wait command.
function experienced_request(obs,records,pressure,owner,other,seed;relation=nothing)
    check(obs["self_id"]==owner && pressure.parent.goal_id==owner*":obtain-aid","request_owner")
    contact=findfirst(x->x["ref"]==other,obs["others"])
    check(contact!==nothing,"request_unobserved_partner")
    sources=String[];weight=0.
    for (id,r) in (relation===nothing && !hasproperty(pressure,:loop) ? records : D())
        check(r["agent_id"]==owner,"request_source_owner")
        r["target"]==other && r["outcome"]=="refuse" || continue
        evidence=pressure.methods[other].records[id]
        check(evidence["E"]==1 && evidence["evidence"]["source"]==r["source_observation_id"],"request_evidence")
        push!(sources,id);weight=max(weight,min(2.,.6*evidence["H_after"]))
    end
    relation!==nothing && check(relation["actor"]==owner,"request_relation_owner")
    unified=hasproperty(pressure,:loop)
    situation=social_observed_context(relation,other,D("need"=>body_observed_demand(obs["body"])))
    relationship=relation===nothing ? nothing : unified ?
        social_relation_bias(relation,other,"request";situation,H=pressure.parent.H) :
        social_relation_bias(relation,other,"request")
    if unified
        # The target loop has already chosen among partners and continuing the
        # activity. This is only a feasibility check, not a second weighted draw.
        selected=obs["others"][contact]["holding_food"] || food_anxiety(food_security(relation))>0
        trace=D("source"=>seed,"other"=>other,"question"=>"request_again","weight"=>0.,"sources"=>String[],
            "request_probability"=>selected ? 1. : 0.,"draw"=>nothing,
            "selected"=>selected ? "request" : "existing_activity","selection"=>"common_target_already_selected")
        relationship!==nothing && (trace["relationship"]=relationship)
        return selected,trace
    end
    score=1-weight+(relationship===nothing ? 0. : relationship["weight"])
    probability=obs["others"][contact]["holding_food"] ? exp(score)/(1+exp(score)) : 0.
    bits=foldl((x,b)->(x<<8)|UInt64(b),sha256(seed)[1:8];init=UInt64(0))
    draw=Float64(bits)/18446744073709551616.0
    selected=draw>=1-probability
    trace=D("source"=>seed,"other"=>other,"question"=>"request_again","weight"=>weight,"sources"=>sources,
        "request_probability"=>probability,"draw"=>draw,"selected"=>selected ? "request" : "existing_activity")
    relationship!==nothing && (trace["relationship"]=relationship)
    selected,trace
end
