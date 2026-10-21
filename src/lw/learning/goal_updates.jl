function ginitial(id,model="home-trial-confirmation-hypothesis-v1",dim="home_confirmed",theta=2,parent=nothing)
    check(all(x->x isa String && !isempty(x),(id,model,dim)),"goal_contract")
    check(theta isa Int && !(theta isa Bool) && theta>=1,"goal_threshold")
    check(parent!=id,"goal_parent")
    GoalState(id,model,dim,parent,0,theta,Records(),nothing)
end
gmethod(s,enabled,primary,alternative)=enabled && s.H>=s.threshold ? alternative : primary
function gbegin(state,id,source)
    s=deepcopy(state)
    trial=D("trial_id"=>id,"source"=>deepcopy(source),"model_ref"=>s.model_ref,
        "goal_id"=>s.goal_id,"dimension"=>s.dimension,"F"=>D(s.dimension=>1))
    if s.trial!==nothing
        check(s.trial==trial,"goal_trial_active");return s
    end
    check(!haskey(s.records,id),"goal_trial_closed");s.trial=trial;s
end
function gfinish(state,id,confirmed,comparable,source)
    check(confirmed isa Bool && comparable isa Bool,"goal_evidence")
    s=deepcopy(state)
    compared=haskey(state.records,id) ? state.records[id]["trial"] : state.trial
    if compared!==nothing && get(compared,"interrupted_by_safety",false) && !confirmed
        comparable=false
    end
    evidence=D("confirmed"=>confirmed,"comparable"=>comparable,"source"=>source)
    if haskey(s.records,id)
        check(s.records[id]["evidence"]==evidence,"goal_trial_conflict");return s
    end
    trial=s.trial;check(trial!==nothing && trial["trial_id"]==id,"goal_trial_binding")
    E=comparable ? (confirmed ? 0 : 1) : nothing;before=s.H
    comparable && (s.H=confirmed ? 0 : before+E)
    s.records[id]=D("trial"=>deepcopy(trial),"evidence"=>evidence,
        "F_prime"=>comparable ? D(trial["dimension"]=>Int(confirmed)) : nothing,
        "E"=>E,"H_before"=>before,"H_after"=>s.H,"status"=>comparable ? "compared" : "defer")
    s.trial=nothing;s
end
function pressure_update(previous,records,actor,theta=2)
    s=previous===nothing ? AidPressure(ginitial(actor*":obtain-aid","received-aid-within-request-window-v1","aid_received",theta),Dict{String,GoalState}()) : deepcopy(previous)
    check(s.parent.goal_id==actor*":obtain-aid","aid_pressure_binding")
    for (id,r) in records
        check(r["agent_id"]==actor,"aid_pressure_agent")
        haskey(s.parent.records,id) && continue
        target=r["target"]
        if !haskey(s.methods,target)
            s.methods[target]=ginitial(actor*":request:"*target,"received-aid-within-request-window-v1","aid_received",theta,s.parent.goal_id)
        end
        source=D("observation_id"=>r["request_observation_id"])
        confirmed=r["outcome"]=="given";comparable=r["outcome"]!="request_not_executed"
        s.parent=gfinish(gbegin(s.parent,id,source),id,confirmed,comparable,r["source_observation_id"])
        s.methods[target]=gfinish(gbegin(s.methods[target],id,source),id,confirmed,comparable,r["source_observation_id"])
    end
    s
end
