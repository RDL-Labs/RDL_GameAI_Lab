# Experimental gameai_local API. One owner updates; snapshots are explicit.
struct AidNotice
    actor::String
    id::String
    target::String
    outcome::String
    request::String
    result::String
end
Base.:(==)(a::AidNotice,b::AidNotice)=all(getfield(a,k)==getfield(b,k) for k in fieldnames(AidNotice))
function aid_notice(id,r)
    fields=(r["agent_id"],id,r["target"],r["outcome"],r["request_observation_id"],r["source_observation_id"])
    check(all(x->x isa String && !isempty(x),fields),"aid_notice_fields")
    check(fields[4] in ("given","refuse","no_response_observed","request_not_executed"),"aid_notice_outcome")
    AidNotice(fields...)
end
mutable struct LiveAid
    actor::String
    state::AidPressure
    seen::Dict{String,AidNotice}
end
live_aid(actor,theta=3)=LiveAid(actor,pressure_update(nothing,Records(),actor,theta),Dict{String,AidNotice}())
pressure_snapshot(live::LiveAid)=deepcopy(live.state)
function pressure_poll!(live,records,accepted_count)
    count=length(records)
    check(count in (accepted_count,accepted_count+1),"aid_append_contract")
    notice=count==accepted_count ? nothing : aid_notice(last(records.order),records[last(records.order)])
    pressure_update!(live,notice)
end

function aid_finish!(s::GoalState,n::AidNotice)
    confirmed=n.outcome=="given";comparable=n.outcome!="request_not_executed"
    trial=D("trial_id"=>n.id,"source"=>D("observation_id"=>n.request),"model_ref"=>s.model_ref,
        "goal_id"=>s.goal_id,"dimension"=>s.dimension,"F"=>D(s.dimension=>1))
    before=s.H;E=comparable ? (confirmed ? 0 : 1) : nothing
    comparable && (s.H=confirmed ? 0 : before+E)
    s.records[n.id]=D("trial"=>trial,"evidence"=>D("confirmed"=>confirmed,"comparable"=>comparable,"source"=>n.result),
        "F_prime"=>comparable ? D(s.dimension=>Int(confirmed)) : nothing,
        "E"=>E,"H_before"=>before,"H_after"=>s.H,"status"=>comparable ? "compared" : "defer")
end
function pressure_update!(live::LiveAid,n::Union{Nothing,AidNotice}=nothing)
    n===nothing && return live.state
    check(n.actor==live.actor,"aid_pressure_agent")
    if haskey(live.seen,n.id)
        check(live.seen[n.id]==n,"aid_notice_conflict");return live.state
    end
    check(length(live.seen)<192,"aid_notice_capacity")
    p=live.state
    check(p.parent.trial===nothing,"aid_active_trial")
    method=get(p.methods,n.target,nothing)
    check(method===nothing || method.trial===nothing,"aid_active_trial")
    if method===nothing
        method=ginitial(live.actor*":request:"*n.target,"received-aid-within-request-window-v1","aid_received",p.parent.threshold,p.parent.goal_id)
        p.methods[n.target]=method
    end
    aid_finish!(p.parent,n);aid_finish!(method,n);live.seen[n.id]=n
    p
end
