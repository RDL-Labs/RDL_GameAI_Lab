# Owner-local food assistance forecasts. The caller supplies only the owner's
# valuation and beliefs; this module cannot read World, another inventory or gut.
const SOCIAL_AID_OUTCOMES=("given","refuse","no_response_observed","request_not_executed","unobserved")
function social_aid_state(actor;seed=0,threshold=3.)
    check(actor isa AbstractString && !isempty(actor),"social_aid_owner")
    D("actor"=>String(actor),"loop"=>BasicLoop(String(actor)*":obtain-aid";
        parent=String(actor)*":food-security",threshold,probabilistic=true,seed),
        "pending"=>nothing,"last_begin_us"=>-1,"last_result"=>nothing,
        "forecasts"=>0,"resolved"=>0,"deferred"=>0,"outcome_counts"=>D(),"records"=>Any[])
end

function social_aid_begin!(s,request_id,target,now;probability,values,
        expected_kind=nothing,kind_probabilities=nothing,deadline_us=now+5_000_000,
        source_refs=String[],mb_ids=String[],context=nothing)
    check(request_id isa AbstractString && !isempty(request_id),"social_aid_request_id")
    check(target isa AbstractString && !isempty(target) && target!=s["actor"],"social_aid_target")
    check(now isa Integer && !(now isa Bool) && 0<=now<deadline_us && deadline_us isa Integer && !(deadline_us isa Bool),"social_aid_deadline")
    check(probability isa Real && !(probability isa Bool) && isfinite(probability) && 0<=probability<=1,"social_aid_probability")
    check(values isa AbstractVector && !isempty(values) && all(v->v isa Real && !(v isa Bool) && isfinite(v) && v>=0,values),"social_aid_values")
    frozen=Float64.(values);kinds=Dict{Int,Float64}()
    if expected_kind!==nothing
        check(expected_kind isa Integer && !(expected_kind isa Bool) && expected_kind in eachindex(frozen),"social_aid_expected_kind")
        kinds[Int(expected_kind)]=1.
    elseif kind_probabilities!==nothing && !isempty(kind_probabilities)
        for (kind,p) in kind_probabilities
            check(kind isa Integer && !(kind isa Bool) && kind in eachindex(frozen),"social_aid_kind")
            check(p isa Real && !(p isa Bool) && isfinite(p) && p>=0,"social_aid_kind_probability")
            kinds[Int(kind)]=Float64(p)
        end
        total=sum(Base.values(kinds));check(total>0,"social_aid_kind_mass")
        for kind in keys(kinds);kinds[kind]/=total;end
    else
        # Unknown content: an explicit uniform prior over known food types,
        # never the unseen distribution in the requested partner's inventory.
        for kind in eachindex(frozen);kinds[kind]=1/length(frozen);end
    end
    expected=Float64(probability)*sum(p*frozen[k] for (k,p) in kinds)
    trial=D("request_id"=>String(request_id),"target"=>String(target),"started_us"=>Int(now),
        "deadline_us"=>Int(deadline_us),"probability"=>Float64(probability),"values"=>frozen,
        "kind_probabilities"=>kinds,"expected"=>expected,"source_refs"=>copy(source_refs),
        "mb_ids"=>copy(mb_ids),"context"=>deepcopy(context))
    if s["pending"]!==nothing
        check(s["pending"]==trial,"social_aid_pending_conflict")
        return deepcopy(trial)
    end
    check(now>s["last_begin_us"],"social_aid_begin_rewind")
    check(s["last_result"]===nothing || s["last_result"]["request_id"]!=request_id,"social_aid_closed_request")
    choose_method!(s["loop"],Any[D("method"=>String(target),"priority"=>expected,
        "question"=>"received_food_value","action"=>"request","target"=>String(target))],String(request_id))
    s["pending"]=trial;s["last_begin_us"]=Int(now);s["forecasts"]+=1
    deepcopy(trial)
end

function social_aid_finish!(s,request_id,target,outcome,now;received_kind=nothing,source=nothing)
    check(outcome in SOCIAL_AID_OUTCOMES,"social_aid_outcome")
    check(now isa Integer && !(now isa Bool) && now>=0,"social_aid_result_time")
    check(received_kind===nothing || (outcome=="given" && received_kind isa Integer && !(received_kind isa Bool)),"social_aid_received_kind")
    evidence=D("request_id"=>String(request_id),"target"=>String(target),"outcome"=>String(outcome),
        "us"=>Int(now),"received_kind"=>received_kind,"source"=>source)
    previous=s["last_result"]
    if previous!==nothing && previous["request_id"]==request_id
        check(previous["evidence"]==evidence,"social_aid_result_conflict")
        return deepcopy(previous)
    end
    trial=s["pending"]
    check(trial!==nothing && trial["request_id"]==request_id && trial["target"]==target,"social_aid_result_binding")
    check(now>=trial["started_us"],"social_aid_result_rewind")
    check(outcome!="no_response_observed" || now>=trial["deadline_us"],"social_aid_early_timeout")
    received_kind!==nothing && check(received_kind in eachindex(trial["values"]),"social_aid_received_kind")
    executed=outcome!="request_not_executed"
    observed=outcome!="unobserved" && !(outcome=="given" && received_kind===nothing)
    actual=outcome=="given" ? (received_kind===nothing ? nothing : trial["values"][received_kind]) : 0.
    resolve_prediction!(s["loop"],request_id,trial["expected"],actual;
        executed,observed,fulfilled=outcome=="given")
    event=last(s["loop"].events)
    result=merge(copy(evidence),D("evidence"=>evidence,"forecast"=>deepcopy(trial),
        "actual"=>actual,"expected"=>trial["expected"],"evaluated"=>event.evaluated,
        "pressure"=>event.goal_H_increment,"relief"=>event.relief,"reward"=>event.reward,
        "H_before"=>event.goal_H_before,"H_after"=>event.goal_H_after))
    s["pending"]=nothing;s["last_result"]=result;s["resolved"]+=1
    counts=get!(() -> D(k=>0 for k in SOCIAL_AID_OUTCOMES),s["outcome_counts"],String(target))
    counts[outcome]+=1
    !event.evaluated && (s["deferred"]+=1)
    push!(s["records"],result);length(s["records"])>32 && popfirst!(s["records"])
    deepcopy(result)
end

function social_aid_pressure(s)
    loop=s["loop"]
    (parent=(goal_id=loop.goal,H=loop.H,threshold=loop.threshold),methods=loop.methods,loop=loop)
end
function social_aid_snapshot(s)
    D("rule"=>"owner-food-forecast-v1","actor"=>s["actor"],"parent"=>loop_snapshot(s["loop"]),
        "pending"=>deepcopy(s["pending"]),"forecasts"=>s["forecasts"],"resolved"=>s["resolved"],
        "deferred"=>s["deferred"],"outcome_counts"=>deepcopy(s["outcome_counts"]),"records"=>deepcopy(s["records"]))
end
