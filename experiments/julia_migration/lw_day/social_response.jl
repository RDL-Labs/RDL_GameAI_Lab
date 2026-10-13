using SHA
# Port of runtime/refusal_relation_field.py's respond path (affiliation=0).
function experienced_response(obs,records,pressure,owner,seed)
    check(obs["self_id"]==owner && pressure.parent.goal_id==owner*":obtain-aid","response_owner")
    m=first(obs["messages"]);other=m["sender"]
    if m["kind"]!="request" || !any(x->x["ref"]==other,obs["others"])
        return response(obs,true),nothing
    end
    sources=String[];weight=0.
    for (id,r) in records
        check(r["agent_id"]==owner,"response_source_owner")
        r["target"]==other && r["outcome"]=="refuse" || continue
        evidence=pressure.methods[other].records[id]
        check(evidence["E"]==1 && evidence["evidence"]["source"]==r["source_observation_id"],"response_evidence")
        push!(sources,id);weight=max(weight,min(2.,.6*evidence["H_after"]))
    end
    reserve=obs["body"]["reserve"];need=max(0.,(80-reserve)/40)
    score=1.-need-weight
    probability=obs["inventory"]>0 ? exp(score)/(1+exp(score)) : 0.
    digest=sha256(seed);bits=foldl((x,b)->(x<<8)|UInt64(b),digest[1:8];init=UInt64(0))
    draw=Float64(bits)/18446744073709551616.0
    action=draw<1-probability ? "refuse" : "give"
    trace=D("source"=>seed,"other"=>other,"weight"=>weight,"sources"=>sources,
        "need"=>need,"give_probability"=>probability,"draw"=>draw,"selected"=>action,
        "authority"=>"local response use rule; not inferred intent")
    (action,other,m["id"]),trace
end
