using SHA
# Port of runtime/refusal_relation_field.py's respond path (affiliation=0).
function experienced_response(obs,records,pressure,owner,seed;retention=0.,relation=nothing)
    check(obs["self_id"]==owner && pressure.parent.goal_id==owner*":obtain-aid","response_owner")
    m=first(obs["messages"]);other=m["sender"]
    if m["kind"]!="request" || !any(x->x["ref"]==other,obs["others"])
        return response(obs,true),nothing
    end
    sources=String[];weight=0.
    for (id,r) in (relation===nothing && !hasproperty(pressure,:loop) ? records : D())
        check(r["agent_id"]==owner,"response_source_owner")
        r["target"]==other && r["outcome"]=="refuse" || continue
        evidence=pressure.methods[other].records[id]
        check(evidence["E"]==1 && evidence["evidence"]["source"]==r["source_observation_id"],"response_evidence")
        push!(sources,id);weight=max(weight,min(2.,.6*evidence["H_after"]))
    end
    relation!==nothing && check(relation["actor"]==owner,"response_relation_owner")
    unified=hasproperty(pressure,:loop)
    situation=social_observed_context(relation,other,D("need"=>clamp((80-obs["body"]["reserve"])/80,0.,1.)))
    relationship=relation===nothing ? nothing : unified ?
        social_relation_bias(relation,other,"give";situation,H=pressure.parent.H) :
        social_relation_bias(relation,other,"give")
    relationship!==nothing && (relationship["applies_to"]="give")
    reserve=obs["body"]["reserve"];need=max(0.,(80-reserve)/40)
    score=1.0 - need - weight - retention - food_anxiety(food_security(relation)) + get(situation,"distress",0.) + (relationship===nothing ? 0. : relationship["weight"])
    probability=if obs["inventory"]<=0
        0.
    elseif unified
        method_distribution(pressure.loop,Any[
            D("method"=>"refuse:"*other,"priority"=>0.),
            D("method"=>"give:"*other,"priority"=>score)])[2]
    else
        exp(score)/(1+exp(score))
    end
    digest=sha256(seed);bits=foldl((x,b)->(x<<8)|UInt64(b),digest[1:8];init=UInt64(0))
    draw=Float64(bits)/18446744073709551616.0
    action=draw<1-probability ? "refuse" : "give"
    trace=D("source"=>seed,"other"=>other,"weight"=>weight,"sources"=>sources,
        "need"=>need,"retention_cost"=>retention,"give_probability"=>probability,"draw"=>draw,"selected"=>action,
        "authority"=>"local response use rule; not inferred intent")
    unified && (trace["selection"]="common_H_distribution")
    relationship!==nothing && (trace["relationship"]=relationship)
    (action,other,m["id"]),trace
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
    situation=social_observed_context(relation,other,D("need"=>clamp((80-obs["body"]["reserve"])/80,0.,1.)))
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
