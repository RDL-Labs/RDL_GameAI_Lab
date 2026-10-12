# A1 GameAI-local parity. Not canonical E/H/T1.
const D=Dict{String,Any}
mutable struct Records <: AbstractDict{String,Any}
    data::D
    order::Vector{String}
end
Records()=Records(D(),String[])
Base.length(r::Records)=length(r.order)
Base.iterate(r::Records,i=1)=i>length(r.order) ? nothing : (r.order[i]=>r.data[r.order[i]],i+1)
Base.getindex(r::Records,k)=r.data[k]
Base.get(r::Records,k,default)=get(r.data,k,default)
Base.haskey(r::Records,k)=haskey(r.data,k)
Base.keys(r::Records)=r.order
function Base.setindex!(r::Records,v,k)
    haskey(r,k) || push!(r.order,k)
    r.data[k]=v
end
check(c,code)=c || error(code)

function ginitial(id,model="home-trial-confirmation-hypothesis-v1",dim="home_confirmed",theta=2,parent=nothing)
    check(all(x->x isa String && !isempty(x),(id,model,dim)),"goal_contract")
    check(theta isa Int && !(theta isa Bool) && theta>=1,"goal_threshold")
    check(parent!=id,"goal_parent")
    D("goal_id"=>id,"model_ref"=>model,"dimension"=>dim,"parent_goal_id"=>parent,
      "H"=>0,"threshold"=>theta,"records"=>Records(),"trial"=>nothing)
end
gmethod(s,enabled,primary,alternative)=enabled && s["H"]>=s["threshold"] ? alternative : primary
function gbegin(state,id,source)
    s=deepcopy(state)
    trial=D("trial_id"=>id,"source"=>deepcopy(source),"model_ref"=>s["model_ref"],
        "goal_id"=>s["goal_id"],"dimension"=>s["dimension"],"F"=>D(s["dimension"]=>1))
    if s["trial"]!==nothing
        check(s["trial"]==trial,"goal_trial_active");return s
    end
    check(!haskey(s["records"],id),"goal_trial_closed");s["trial"]=trial;s
end
function gfinish(state,id,confirmed,comparable,source)
    check(confirmed isa Bool && comparable isa Bool,"goal_evidence")
    s=deepcopy(state)
    compared=haskey(state["records"],id) ? state["records"][id]["trial"] : state["trial"]
    if compared!==nothing && get(compared,"interrupted_by_safety",false) && !confirmed
        comparable=false
    end
    evidence=D("confirmed"=>confirmed,"comparable"=>comparable,"source"=>source)
    if haskey(s["records"],id)
        check(s["records"][id]["evidence"]==evidence,"goal_trial_conflict");return s
    end
    trial=s["trial"];check(trial!==nothing && trial["trial_id"]==id,"goal_trial_binding")
    E=comparable ? (confirmed ? 0 : 1) : nothing;before=s["H"]
    comparable && (s["H"]=confirmed ? 0 : before+E)
    s["records"][id]=D("trial"=>deepcopy(trial),"evidence"=>evidence,
        "F_prime"=>comparable ? D(trial["dimension"]=>Int(confirmed)) : nothing,
        "E"=>E,"H_before"=>before,"H_after"=>s["H"],"status"=>comparable ? "compared" : "defer")
    s["trial"]=nothing;s
end
function pressure_update(previous,records,actor,theta=2)
    s=previous===nothing ? D("parent"=>ginitial(actor*":obtain-aid","received-aid-within-request-window-v1","aid_received",theta),"methods"=>D()) : deepcopy(previous)
    check(s["parent"]["goal_id"]==actor*":obtain-aid","aid_pressure_binding")
    for (id,r) in records
        check(r["agent_id"]==actor,"aid_pressure_agent")
        haskey(s["parent"]["records"],id) && continue
        target=r["target"]
        if !haskey(s["methods"],target)
            s["methods"][target]=ginitial(actor*":request:"*target,"received-aid-within-request-window-v1","aid_received",theta,s["parent"]["goal_id"])
        end
        source=D("observation_id"=>r["request_observation_id"])
        confirmed=r["outcome"]=="given";comparable=r["outcome"]!="request_not_executed"
        s["parent"]=gfinish(gbegin(s["parent"],id,source),id,confirmed,comparable,r["source_observation_id"])
        s["methods"][target]=gfinish(gbegin(s["methods"][target],id,source),id,confirmed,comparable,r["source_observation_id"])
    end
    s
end
function select_target(targets,model,pressure)
    candidates=Any[]
    for target in sort(unique(targets))
        state=get(pressure["methods"],target,nothing)
        H=state===nothing ? 0 : state["H"]
        theta=state===nothing ? pressure["parent"]["threshold"] : state["threshold"]
        penalty=H>=theta ? min(2,H/theta) : 0
        push!(candidates,D("target"=>target,"H"=>H,"threshold"=>theta,
            "score"=>get(get(model,target,D()),"expectation",.5)-penalty))
    end
    if pressure["parent"]["H"]>=pressure["parent"]["threshold"]
        push!(candidates,D("target"=>nothing,"score"=>.25,"reason"=>"reconsider_existing_activity"))
    end
    chosen=isempty(candidates) ? nothing : candidates[argmin([(-c["score"],c["target"]===nothing ? "" : c["target"]) for c in candidates])]
    (chosen===nothing ? nothing : chosen["target"],D("candidates"=>candidates,"selected"=>deepcopy(chosen)))
end
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

const DAY=17_280_000_000
const REST=2_880_000_000
function sleeper(day,rest=0)
    D("sleep"=>D("cycle"=>D("day"=>day,"status"=>"pending","rest_us"=>rest,"records"=>Any[],
        "source"=>"night","result"=>nothing,"relation_materials"=>D("records"=>Any[],"window"=>D()),"relation_review"=>nothing),"completed"=>Any[]))
end
function receipt!(learning,now;phase="night",status="waited",pose=true,kind="wait",accepted=true)
    check(accepted,"sleep_result_not_accepted")
    c=learning["sleep"]["cycle"]
    c["status"]!="pending" && return false
    executed=now+1_000_000
    executed<=get(c,"last_rest_executed_us",-1) && return false
    c["day"]!=div(now,DAY) && return false
    valid=phase=="night" && kind=="wait" && status=="waited" && pose && now<executed<=(c["day"]+1)*DAY
    c["last_rest_operation"]="op:$now";c["last_rest_executed_us"]=executed
    c["rest_us"]=valid ? c["rest_us"]+1_000_000 : 0
    if c["rest_us"]>=REST
        # Explicit empty-harvest-material branch, not general relation inspection.
        check(isempty(c["records"]) && isempty(c["relation_materials"]["records"]),"unported_sleep_material")
        c["relation_review"]=D("rule"=>"cross-action-sleep-review-v1","status"=>"insufficient_records",
            "window"=>D(),"records"=>Any[],"profiles"=>Any[],"pair_results"=>Any[],"candidate_admission"=>"none",
            "authority"=>"matches/differences/missing only; no causal inference, support amplification or M_B update")
        c["status"]="completed";c["result"]=D("status"=>"INSUFFICIENT_EVIDENCE","reason"=>nothing,"model_ref"=>nothing)
        c["completed_us"]=executed
    end
    true
end
