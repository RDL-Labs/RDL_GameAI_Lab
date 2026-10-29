# GameAI-local social relation MBs. Conditions describe the owner's choice;
# received food and personal utility are consequences, never hidden peer state.
# Feature vocabulary, priors and storage budgets are initial adapters. Outcome
# predictions and the similarity metric change from experienced consequences.
const SOCIAL_MB_PENDING_LIMIT=128
const SOCIAL_MB_NODE_LIMIT=96
const SOCIAL_MB_CONTEXT_KEYS=("give_kind","want_kind","give_count","want_count","need")
social_mb_state()=D("nodes"=>D(),"pending"=>D(),"frozen"=>nothing,
    "metric"=>mb_metric_state(),"reviews"=>Any[],"last_review_day"=>-1,
    "events"=>0,"unknown"=>0,"admission_blocked"=>0,"provisional_evicted"=>0,"merged"=>0,"evicted"=>0)
social_relational(s)=s!==nothing && get(s,"relational",false)

function social_mb_context(context)
    context===nothing && return D()
    out=D()
    for (key,value) in pairs(context)
        k=String(key);check(k in SOCIAL_MB_CONTEXT_KEYS,"social_mb_context_key")
        check(value isa Real && !(value isa Bool) && isfinite(value),"social_mb_context_value")
        if k in ("give_kind","want_kind")
            check(isinteger(value) && 1<=value<=4,"social_mb_context_kind")
            out[k]=Int(value)
        elseif k in ("give_count","want_count")
            check(isinteger(value) && 0<=value<=4,"social_mb_context_count")
            out[k]=Int(value)
        else
            check(0<=value<=2,"social_mb_context_need");out[k]=Float64(value)
        end
    end
    out
end
function social_mb_key(other,channel,context)
    # Quantization is only an admission/storage boundary; query uses the actual
    # current context and a soft similarity, not exact-key recognition.
    parts=[k*"="*string(k=="need" ? round(context[k];digits=2) : context[k]) for k in sort(collect(keys(context)))]
    other*"|"*channel*"|"*join(parts,",")
end
function social_mb_node(other,channel,context,source,now)
    D("other"=>other,"channel"=>channel,"context"=>deepcopy(context),
        "samples"=>0,"successes"=>0,"value_samples"=>0,"value_sum"=>0.,
        "food_kinds"=>Dict{Int,Int}(),"source_refs"=>String[],"source_count"=>0,
        "source_digest"=>"","first_us"=>now,"last_us"=>now,"last_outcome"=>nothing,
        "last_value"=>0.,"represented"=>1)
end
function social_mb_merge!(a,b)
    for k in ("samples","successes","value_samples","source_count")
        a[k]+=b[k]
    end
    a["value_sum"]+=b["value_sum"]
    for (k,n) in b["food_kinds"];a["food_kinds"][k]=get(a["food_kinds"],k,0)+n;end
    a["source_refs"]=unique(vcat(a["source_refs"],b["source_refs"]))
    length(a["source_refs"])>16 && deleteat!(a["source_refs"],1:length(a["source_refs"])-16)
    a["source_digest"]=bytes2hex(sha256(a["source_digest"]*":"*b["source_digest"]))
    a["first_us"]=min(a["first_us"],b["first_us"])
    if b["last_us"]>=a["last_us"]
        for k in ("last_us","last_outcome","last_value");a[k]=b[k];end
    end
    a
end
function social_mb_parts(a,b)
    common=intersect(keys(a),keys(b))
    isempty(common) && return nothing
    kinds=String[k for k in common if k in ("give_kind","want_kind")]
    numeric=String[k for k in common if !(k in kinds)]
    categorical=isempty(kinds) ? 0. : sum(a[k]!=b[k] for k in kinds)/length(kinds)
    continuous=isempty(numeric) ? 0. : sum(abs(a[k]-b[k])/(k=="need" ? 1. : 4.) for k in numeric)/length(numeric)
    [(Float64(categorical),Float64(continuous))]
end
function social_mb_fit(metric,query,stored)
    parts=social_mb_parts(query,stored)
    # Missing conditions are unknown. General experience is still a weaker clue.
    parts===nothing && return isempty(query) && isempty(stored) ? 1. : .5
    coverage=length(intersect(keys(query),keys(stored)))/max(length(query),length(stored))
    x=first(parts);weights=metric["weights"]
    exp(-weights[1]*x[1]-weights[2]*x[2])*(.5+.5coverage)
end
function social_mb_groups(m)
    frozen=m["frozen"]
    frozen===nothing ? (m["nodes"],m["pending"]) : (m["nodes"],m["pending"],frozen["candidates"])
end
function social_mb_record!(s,event)
    social_relational(s) || return
    m=s["mb"];m["events"]+=1
    outcome=event["outcome"]
    if outcome in ("no_response_observed","request_not_executed","expired","unavailable")
        m["unknown"]+=1;return
    end
    other=event["other"];channel=event["channel"];context=event["context"]
    success=outcome in ("given","transferred","exchanged")
    # Reuse the navigation correspondence metric's bounded update rule. The
    # teacher is an actually observed outcome/value, not our predicted identity.
    examples=Any[]
    for group in social_mb_groups(m), node in values(group)
        node["other"]==other && node["channel"]==channel && push!(examples,node)
    end
    sort!(examples,by=n->(-n["samples"],n["first_us"]))
    for previous in Iterators.take(examples,8)
        parts=social_mb_parts(context,previous["context"]);parts===nothing && continue
        previous_success=previous["last_outcome"] in ("given","transferred","exchanged")
        same=previous_success==success && (!success || abs(previous["last_value"]-event["value"])<=.25)
        mb_metric_update!(m["metric"],parts,same ? 1. : 0.,event["source"])
    end
    key=social_mb_key(other,channel,context)
    if !haskey(m["pending"],key) && length(m["pending"])>=SOCIAL_MB_PENDING_LIMIT
        m["admission_blocked"]+=1;return
    end
    node=get!(() -> social_mb_node(other,channel,context,event["source"],event["us"]),m["pending"],key)
    node["samples"]+=1;node["successes"]+=Int(success)
    if success
        node["value_samples"]+=1;node["value_sum"]+=event["value"]
        kind=event["food_kind"]
        kind>0 && (node["food_kinds"][kind]=get(node["food_kinds"],kind,0)+1)
    end
    ref=channel*":"*event["source"]
    push!(node["source_refs"],ref);length(node["source_refs"])>16 && popfirst!(node["source_refs"])
    node["source_count"]+=1;node["source_digest"]=bytes2hex(sha256(node["source_digest"]*":"*ref))
    node["last_us"]=event["us"];node["last_outcome"]=outcome;node["last_value"]=event["value"]
    nothing
end

function social_mb_predict(s,other,channel;situation=nothing,H=0.)
    check(channel in keys(SOCIAL_RELATION_OUTCOMES),"social_mb_channel")
    check(H isa Real && isfinite(H) && H>=0,"social_mb_H")
    query=social_mb_context(situation)
    prior=D("probability"=>.5,"value_mean"=>0.,"evidence"=>0.,"success_evidence"=>0.,
        "value_evidence"=>0.,"kind_probabilities"=>Dict{Int,Float64}(),"mb_ids"=>String[],
        "source_refs"=>String[],"matches"=>Any[],"status"=>"unknown")
    social_relational(s) || return prior
    m=s["mb"];ranked=Any[]
    for (i,group) in enumerate(social_mb_groups(m)), (key,node) in group
        node["other"]==other && node["channel"]==channel || continue
        fit=social_mb_fit(m["metric"],query,node["context"])
        push!(ranked,(key=string(i)*":"*key,node=node,fit=fit,strength=fit*log1p(node["samples"])))
    end
    isempty(ranked) && return prior
    sort!(ranked,by=x->(-x.strength,x.key))
    width=min(8,mb_retrieval_budget(H))
    # Weak fit expands the same finite retrieval budget; uncertainty does not
    # certify a mismatch or eliminate all alternatives.
    first(ranked).fit<.5 && (width=8)
    chosen=Iterators.take(ranked,width)
    total=0.;success=0.;value_sum=0.;value_n=0.;kinds=Dict{Int,Float64}();refs=String[];ids=String[];matches=Any[]
    for x in chosen
        n=x.node;w=x.fit
        total+=w*n["samples"];success+=w*n["successes"]
        value_sum+=w*n["value_sum"];value_n+=w*n["value_samples"]
        for (k,count) in n["food_kinds"];kinds[k]=get(kinds,k,0.)+w*count;end
        append!(refs,n["source_refs"]);push!(ids,x.key)
        push!(matches,D("id"=>x.key,"fit"=>w,"samples"=>n["samples"],"state"=>startswith(x.key,"1:") ? "adopted" : "provisional"))
    end
    mass=sum(values(kinds));mass>0 && foreach(k->kinds[k]/=mass,keys(kinds))
    unique!(refs);length(refs)>32 && deleteat!(refs,1:length(refs)-32)
    D("probability"=>(1+success)/(2+total),"value_mean"=>value_n>0 ? value_sum/value_n : 0.,
        "evidence"=>total,"success_evidence"=>success,"value_evidence"=>value_n,
        "kind_probabilities"=>kinds,"mb_ids"=>ids,"source_refs"=>refs,"matches"=>matches,
        "status"=>"owner_experience_prediction")
end

function social_mb_sleep_freeze!(s,day,now)
    social_relational(s) || return false
    m=s["mb"];day<=m["last_review_day"] && return false
    frozen=m["frozen"]
    frozen!==nothing && frozen["day"]==day && return false
    if frozen!==nothing
        # An interrupted sleep never silently discards its candidate evidence.
        for (key,node) in frozen["candidates"]
            if haskey(m["pending"],key);social_mb_merge!(m["pending"][key],node)
            else;m["pending"][key]=node;end
        end
        # Repeated interrupted nights cannot grow a hidden, unlimited archive.
        # Keep strongest provisional relations and explicitly count budget loss.
        ordered=sort(collect(keys(m["pending"])),by=k->(-m["pending"][k]["samples"],k))
        for key in Iterators.drop(ordered,SOCIAL_MB_PENDING_LIMIT)
            delete!(m["pending"],key);m["provisional_evicted"]+=1
        end
    end
    m["frozen"]=D("day"=>Int(day),"formation_us"=>Int(now),"candidates"=>m["pending"])
    m["pending"]=D()
    true
end
function social_mb_merge_compatible(a,b,metric)
    a["other"]==b["other"] && a["channel"]==b["channel"] || return false
    # Storage compression preserves food identity and unknown conditions. The
    # query remains probabilistic, including across different food identities.
    keys(a["context"])==keys(b["context"]) || return false
    all(get(a["context"],k,nothing)==get(b["context"],k,nothing) for k in ("give_kind","want_kind")) || return false
    social_mb_fit(metric,a["context"],b["context"])>=.8 || return false
    abs(a["successes"]/a["samples"]-b["successes"]/b["samples"])<=.2 || return false
    av=a["value_samples"]==0 ? 0. : a["value_sum"]/a["value_samples"]
    bv=b["value_samples"]==0 ? 0. : b["value_sum"]/b["value_samples"]
    abs(av-bv)<=.2
end
function social_mb_sleep_review!(s,day,now;completed=true)
    social_relational(s) || return false
    m=s["mb"];completed && day>m["last_review_day"] || return false
    f=m["frozen"];f!==nothing && f["day"]==day && now>f["formation_us"] || return false
    before=length(m["nodes"]);merged=0;admitted=0
    for key in sort(collect(keys(f["candidates"])))
        b=f["candidates"][key]
        rep=haskey(m["nodes"],key) ? key : nothing
        if rep===nothing
            compatible=sort([k for (k,a) in m["nodes"] if social_mb_merge_compatible(a,b,m["metric"])])
            !isempty(compatible) && (rep=first(compatible))
        end
        if rep===nothing
            m["nodes"][key]=deepcopy(b);admitted+=1
        else
            social_mb_merge!(m["nodes"][rep],b);rep!=key && (m["nodes"][rep]["represented"]+=b["represented"])
            merged+=1
        end
    end
    # No freshness decay. Under a storage bound retain the most supported
    # relations; an eviction is recorded and does not undo world/ledger history.
    ordered=sort(collect(keys(m["nodes"])),by=k->(-m["nodes"][k]["samples"],k))
    evicted=max(0,length(ordered)-SOCIAL_MB_NODE_LIMIT)
    for key in Iterators.drop(ordered,SOCIAL_MB_NODE_LIMIT);delete!(m["nodes"],key);end
    m["merged"]+=merged;m["evicted"]+=evicted;m["last_review_day"]=Int(day)
    push!(m["reviews"],D("day"=>day,"formation_us"=>f["formation_us"],"completed_us"=>now,
        "before"=>before,"candidates"=>length(f["candidates"]),"admitted"=>admitted,"merged"=>merged,
        "evicted"=>evicted,"retained"=>length(m["nodes"])))
    length(m["reviews"])>32 && popfirst!(m["reviews"])
    m["frozen"]=nothing
    true
end
