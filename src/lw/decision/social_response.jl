using SHA
# Port of runtime/refusal_relation_field.py's respond path (affiliation=0).
function experienced_response(obs,records,pressure,owner,seed;retention=0.,relation=nothing)
    check(obs["self_id"]==owner && pressure.parent.goal_id==owner*":obtain-aid","response_owner")
    m=first(obs["messages"]);other=m["sender"]
    if m["kind"]!="request" || !any(x->x["ref"]==other,obs["others"])
        return response(obs,true),nothing
    end
    sources=String[];weight=0.
    for (id,r) in (relation===nothing ? records : D())
        check(r["agent_id"]==owner,"response_source_owner")
        r["target"]==other && r["outcome"]=="refuse" || continue
        evidence=pressure.methods[other].records[id]
        check(evidence["E"]==1 && evidence["evidence"]["source"]==r["source_observation_id"],"response_evidence")
        push!(sources,id);weight=max(weight,min(2.,.6*evidence["H_after"]))
    end
    relation!==nothing && check(relation["actor"]==owner,"response_relation_owner")
    relationship=relation===nothing ? nothing : social_relation_bias(relation,other,"give")
    relationship!==nothing && (relationship["applies_to"]="give")
    reserve=obs["body"]["reserve"];need=max(0.,(80-reserve)/40)
    score=1.0 - need - weight - retention + (relationship===nothing ? 0. : relationship["weight"])
    probability=obs["inventory"]>0 ? exp(score)/(1+exp(score)) : 0.
    digest=sha256(seed);bits=foldl((x,b)->(x<<8)|UInt64(b),digest[1:8];init=UInt64(0))
    draw=Float64(bits)/18446744073709551616.0
    action=draw<1-probability ? "refuse" : "give"
    trace=D("source"=>seed,"other"=>other,"weight"=>weight,"sources"=>sources,
        "need"=>need,"retention_cost"=>retention,"give_probability"=>probability,"draw"=>draw,"selected"=>action,
        "authority"=>"local response use rule; not inferred intent")
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
    for (id,r) in (relation===nothing ? records : D())
        check(r["agent_id"]==owner,"request_source_owner")
        r["target"]==other && r["outcome"]=="refuse" || continue
        evidence=pressure.methods[other].records[id]
        check(evidence["E"]==1 && evidence["evidence"]["source"]==r["source_observation_id"],"request_evidence")
        push!(sources,id);weight=max(weight,min(2.,.6*evidence["H_after"]))
    end
    relation!==nothing && check(relation["actor"]==owner,"request_relation_owner")
    relationship=relation===nothing ? nothing : social_relation_bias(relation,other,"request")
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
