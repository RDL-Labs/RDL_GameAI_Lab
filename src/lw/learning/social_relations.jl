# Owner-local summaries of observed interaction. These are neither another
# actor's intentions nor a single friendship score. Valuation is an initial
# adapter; the current candidate loop retains selection authority.
const SOCIAL_RELATION_CONTEXTS=("request","give","trade_offer","trade_response")
const SOCIAL_RELATION_OUTCOMES=Dict(
    "aid_received"=>("given","refuse","no_response_observed","request_not_executed"),
    "aid_given"=>("transferred","refuse","unavailable"),
    "trade_offer"=>("exchanged","declined","expired","unavailable"),
    "trade_response"=>("exchanged","declined","expired","unavailable"))

include("social_mb.jl")

function social_relations_state(actor;relational=false)
    check(actor isa AbstractString && !isempty(actor),"social_relation_owner")
    s=D("actor"=>String(actor),"peers"=>D(),"current_contacts"=>String[],
        "last_observed_us"=>-1,"records"=>Any[],"choices"=>Any[],
        "use_counts"=>D(c=>0 for c in SOCIAL_RELATION_CONTEXTS),"use_receipts"=>D())
    relational && (s["relational"]=true;s["mb"]=social_mb_state())
    s
end
function social_relation_peer()
    p=D("encounters"=>0,"contact_seconds"=>0.,"last_seen_us"=>nothing,
        "trade_value_sum"=>0.,"trade_value_samples"=>0,
        "trade_positive"=>0,"trade_negative"=>0,"trade_neutral"=>0,
        "receipts"=>D(),"source_refs"=>String[])
    for (channel,outcomes) in SOCIAL_RELATION_OUTCOMES
        p[channel]=D(outcome=>0 for outcome in outcomes)
    end
    p
end
function social_relation_time(now)
    check(now isa Integer && !(now isa Bool) && 0<=now<=typemax(Int),"social_relation_time")
    Int(now)
end
function social_relation_other(s,other)
    check(other isa AbstractString && !isempty(other) && other!=s["actor"],"social_relation_other")
    String(other)
end
function social_relations_observe!(s,obs,now)
    check(obs["self_id"]==s["actor"],"social_relation_observation_owner")
    t=social_relation_time(now);previous=s["last_observed_us"]
    check(t>=previous,"social_relation_observation_rewind")
    t==previous && return s
    contacts=sort(unique([social_relation_other(s,o["ref"]) for o in obs["others"]]))
    # A gap in observation does not establish contact for the whole interval.
    dt=previous<0 ? 0. : min((t-previous)/1e6,1.)
    for other in contacts
        p=get!(social_relation_peer,s["peers"],other)
        if other in s["current_contacts"]
            p["contact_seconds"]+=dt
        else
            p["encounters"]+=1
        end
        p["last_seen_us"]=t
    end
    s["current_contacts"]=contacts;s["last_observed_us"]=t
    s
end

function social_relation_event!(s,other,channel,source,now;outcome,value=0.,context=nothing,food_kind=0)
    other=social_relation_other(s,other);t=social_relation_time(now)
    check(haskey(SOCIAL_RELATION_OUTCOMES,channel),"social_relation_channel")
    check(outcome in SOCIAL_RELATION_OUTCOMES[channel],"social_relation_outcome")
    check(source isa AbstractString && !isempty(source),"social_relation_source")
    check(value isa Real && !(value isa Bool) && isfinite(value),"social_relation_value")
    exchange=channel in ("trade_offer","trade_response") && outcome=="exchanged"
    received=channel=="aid_received" && outcome=="given"
    check(exchange || received || iszero(value),"social_relation_nonexchange_value")
    check(food_kind isa Integer && !(food_kind isa Bool) && 0<=food_kind<=4,"social_relation_food_kind")
    check(received || food_kind==0,"social_relation_food_consequence")
    situation=social_mb_context(context)
    event=D("actor"=>s["actor"],"other"=>other,"channel"=>String(channel),
        "source"=>String(source),"us"=>t,"outcome"=>String(outcome),"value"=>Float64(value))
    (social_relational(s) || context!==nothing || food_kind!=0) && merge!(event,D("context"=>situation,"food_kind"=>Int(food_kind)))
    p=get(s["peers"],other,nothing)
    previous=p===nothing ? nothing : get(p["receipts"],channel,nothing)
    if previous!==nothing
        if previous["source"]==source
            check(previous==event,"social_relation_event_conflict");return false
        end
        # One result per peer/channel/tick; stale delivery cannot revive a
        # pruned receipt or count an earlier result a second time.
        t<=previous["us"] && return false
    end
    p=get!(social_relation_peer,s["peers"],other)
    p[channel][outcome]+=1
    if exchange
        p["trade_value_sum"]+=Float64(value);p["trade_value_samples"]+=1
        p[value>0 ? "trade_positive" : value<0 ? "trade_negative" : "trade_neutral"]+=1
    end
    p["receipts"][String(channel)]=deepcopy(event)
    ref=String(channel)*":"*String(source)
    push!(p["source_refs"],ref);length(p["source_refs"])>16 && popfirst!(p["source_refs"])
    push!(s["records"],event);length(s["records"])>32 && popfirst!(s["records"])
    social_mb_record!(s,event)
    true
end

function social_relation_profile(s,other;situation=nothing,H=0.)
    p=s===nothing ? nothing : get(s["peers"],other,nothing)
    given=p===nothing ? 0 : p["aid_received"]["given"]
    refused=p===nothing ? 0 : p["aid_received"]["refuse"]
    accepted=p===nothing ? 0 : p["trade_offer"]["exchanged"]
    declined=p===nothing ? 0 : p["trade_offer"]["declined"]
    seconds=p===nothing ? 0. : p["contact_seconds"]
    samples=p===nothing ? 0 : p["trade_value_samples"]
    value=p===nothing ? 0. : p["trade_value_sum"]
    last_seen=p===nothing ? nothing : p["last_seen_us"]
    refs=p===nothing ? String[] : copy(p["source_refs"])
    # A compact reference to the actual owner-local observation, retained even
    # when familiarity has not yet been accompanied by an interaction result.
    last_seen!==nothing && push!(refs,"ob:$last_seen:$(s["actor"]):peer:$other")
    profile=D("aid_probability"=>(1+given)/(2+given+refused),
        "trade_probability"=>(1+accepted)/(2+accepted+declined),
        "benefit"=>tanh(value/(2+samples)),"aid_credit"=>given/(2+given),
        "familiarity"=>seconds/(60+seconds),
        "encounters"=>p===nothing ? 0 : p["encounters"],"contact_seconds"=>seconds,
        "last_seen_us"=>last_seen,"source_refs"=>refs)
    if social_relational(s)
        aid=social_mb_predict(s,other,"aid_received";situation,H)
        offered=social_mb_predict(s,other,"trade_offer";situation,H)
        responded=social_mb_predict(s,other,"trade_response";situation,H)
        samples=offered["value_evidence"]+responded["value_evidence"]
        value=offered["value_mean"]*offered["value_evidence"]+responded["value_mean"]*responded["value_evidence"]
        profile["aid_probability"]=aid["probability"];profile["trade_probability"]=offered["probability"]
        profile["aid_credit"]=aid["success_evidence"]/(2+aid["success_evidence"])
        profile["benefit"]=tanh(value/(2+samples))
        profile["predictions"]=D("aid"=>aid,"trade_offer"=>offered,"trade_response"=>responded)
        # Aggregate old statistics stay available for audit, but only sources
        # retrieved for this context justify the active interaction prediction.
        profile["source_refs"]=unique(vcat(aid["source_refs"],offered["source_refs"],responded["source_refs"]))
        last_seen!==nothing && push!(profile["source_refs"],"ob:$last_seen:$(s["actor"]):peer:$other")
    end
    profile
end
function social_relation_bias(s,other,context;situation=nothing,H=0.)
    check(context in SOCIAL_RELATION_CONTEXTS,"social_relation_context")
    p=social_relation_profile(s,other;situation,H)
    benefit=p["benefit"];aid=p["aid_credit"];familiar=p["familiarity"]
    weight=if context=="request"
        .75log(2p["aid_probability"])+.25benefit+.1familiar
    elseif context=="give"
        .75aid+.5benefit+.1familiar
    elseif context=="trade_offer"
        .75log(2p["trade_probability"])+.5benefit+.25aid+.1familiar
    else
        .5benefit+.25aid+.1familiar
    end
    D("weight"=>clamp(weight,-2.,2.),"context"=>String(context),"profile"=>p,
        "source_refs"=>copy(p["source_refs"]),
        "authority"=>social_relational(s) ? "contextual local relation MB prediction; initial use coefficients, not inferred intent or canonical T1" : "owner-local observed interaction summary; not intent or a canonical relationship")
end

function social_relation_use!(s,other,context,source,now,trace;action=nothing)
    s===nothing && return false
    other=social_relation_other(s,other);t=social_relation_time(now)
    check(context in SOCIAL_RELATION_CONTEXTS,"social_relation_context")
    check(source isa AbstractString && !isempty(source),"social_relation_source")
    check(trace["context"]==context && trace["weight"] isa Real &&
        isfinite(trace["weight"]) && -2<=trace["weight"]<=2,"social_relation_trace")
    choice=D("actor"=>s["actor"],"other"=>other,"context"=>String(context),
        "source"=>String(source),"us"=>t,"action"=>action,"trace"=>deepcopy(trace))
    previous=get(s["use_receipts"],context,nothing)
    if previous!==nothing
        if previous["source"]==source
            check(previous==choice,"social_relation_use_conflict");return false
        end
        t<=previous["us"] && return false
    end
    s["use_receipts"][String(context)]=deepcopy(choice)
    s["use_counts"][context]+=1
    push!(s["choices"],choice);length(s["choices"])>32 && popfirst!(s["choices"])
    true
end
function social_relations_snapshot(s)
    s===nothing && return nothing
    out=deepcopy(s)
    haskey(s,"aid") && (out["aid"]=social_aid_snapshot(s["aid"]))
    out
end
