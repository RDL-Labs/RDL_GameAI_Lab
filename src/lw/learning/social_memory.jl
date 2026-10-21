social_initial()=D("records"=>Records(),"pending"=>nothing,"model"=>D(),"cycles"=>Any[])
function ingest(state,packet,results)
    s=state===nothing ? social_initial() : deepcopy(state)
    pending=s["pending"]
    if pending!==nothing
        messages=[m for m in packet["social"]["messages"] if m["reply_to"]==pending["message_id"] &&
            m["sender"]==pending["target"] && m["kind"] in ("given","refuse") && m["time"]*1e6<pending["deadline"]]
        response=isempty(messages) ? nothing : messages[1];own=get(results,pending["operation_id"],nothing)
        if response!==nothing || packet["capture_us"]>=pending["deadline"]
            check(length(s["records"])<192,"social_experience_capacity")
            r=deepcopy(pending)
            merge!(r,D("agent_id"=>packet["agent_id"],"outcome"=>own===nothing || own["status"]!="expressed" ? "request_not_executed" : response===nothing ? "no_response_observed" : response["kind"],
                "source_observation_id"=>packet["observation_id"],"tick"=>packet["capture_us"],"intent"=>"unknown"))
            s["records"][pending["message_id"]]=r;s["pending"]=nothing
        end
    end
    s
end
function consolidate_social(state,cycle,actor)
    s=deepcopy(state)
    (cycle===nothing || cycle["status"]!="completed" || cycle["day"] in s["cycles"]) && return s
    records=collect(values(s["records"]))
    check(all(r->r["agent_id"]==actor,records),"social_source_agent")
    records=[r for r in records if r["tick"]<=cycle["formation_us"] && r["outcome"]!="request_not_executed"]
    for target in sort(unique([r["target"] for r in records]))
        group=[r for r in records if r["target"]==target]
        s["model"][target]=D("expectation"=>(1+count(r->r["outcome"]=="given",group))/(2+length(group)),
            "sources"=>[r["message_id"] for r in group],"authority"=>"unvalidated local aid expectation; not intent or canonical T1")
    end
    push!(s["cycles"],cycle["day"]);s
end
