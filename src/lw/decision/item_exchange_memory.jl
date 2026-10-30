# Observer-owned, bounded relations between observed bundles. References bind
# execution only; prototypes contain features and stated food quantities.
item_exchange_shapes(b)=sort!(unique([(f["color"],f["size"],f["light_source"]) for f in b["items"]]))
item_exchange_key(partner,give,want)=repr((partner,item_exchange_shapes(give),findall(>(0),give["food"]),
    item_exchange_shapes(want),findall(>(0),want["food"])))
item_exchange_quantities(give,want)=vcat(log1p(length(give["items"])),log1p.(give["food"]),
    -log1p(length(want["items"])),.-log1p.(want["food"]))
item_exchange_response(m,give,want)=haskey(m,"quantity_coefficients") ?
    1/(1+exp(-clamp(m["quantity_intercept"]+sum(m["quantity_coefficients"].*item_exchange_quantities(give,want)),-30.,30.))) :
    (1+m["successes"])/(2+m["successes"]+m["failures"])

function item_exchange_accumulate!(memory,give,want,partner,need,successes,failures,now)
    key=item_exchange_key(partner,give,want);i=findfirst(m->m["key"]==key,memory)
    if i===nothing
        length(memory)>=128 && deleteat!(memory,argmin([(m["successes"]>0,m["last_us"]) for m in memory]))
        push!(memory,D("key"=>key,"partner"=>partner,"give"=>deepcopy(give),"want"=>deepcopy(want),
            "need"=>need,"successes"=>0,"failures"=>0,"last_us"=>now,
            "quantity_coefficients"=>fill(.25,10),"quantity_intercept"=>0.,"quantity_observations"=>Any[]))
        i=length(memory)
    end
    m=memory[i];n=successes+failures;n>0 || return m
    x=item_exchange_quantities(give,want);p=item_exchange_response(m,give,want)
    # Weak initial concession prior, revised by observed responses. Coefficients
    # may reverse: no hidden recipient utility or universal monotonic law.
    rate=.2/(1+.01*(m["successes"]+m["failures"]))
    error=successes/n-p
    m["quantity_intercept"]+=rate*error
    m["quantity_coefficients"].+=rate*error.*x
    m["need"]=(m["need"]*(m["successes"]+m["failures"])+need*n)/(m["successes"]+m["failures"]+n)
    m["successes"]+=successes;m["failures"]+=failures;m["last_us"]=max(m["last_us"],now)
    push!(m["quantity_observations"],D("give"=>deepcopy(give),"want"=>deepcopy(want),
        "successes"=>successes,"failures"=>failures,"need"=>need,"us"=>now))
    length(m["quantity_observations"])>32 && popfirst!(m["quantity_observations"])
    # A successful quantity is a seed for local refinement, not a matching key.
    if successes>0;m["give"]=deepcopy(give);m["want"]=deepcopy(want);end
    m
end

function item_exchange_memory!(state)
    memory=get!(state,"exchange_relations",Any[])
    if any(m->!haskey(m,"quantity_coefficients"),memory)
        merged=Any[]
        for m in sort(memory;by=m->(m["last_us"],m["key"]))
            # Old aggregates have no outcome order. Preserve counts once; do not
            # invent repeated trials or reconstruct missing quantity histories.
            item_exchange_accumulate!(merged,m["give"],m["want"],m["partner"],m["need"],m["successes"],m["failures"],m["last_us"])
        end
        state["exchange_relations"]=merged;memory=merged
    end
    memory
end

function item_exchange_neighbors(give,want,gf,wf,owned,visible)
    result=Any[(copy(give),copy(want),copy(gf),copy(wf))]
    for side in 1:2
        ids=side==1 ? give : want;food=side==1 ? gf : wf;rows=side==1 ? owned : visible
        for k in eachindex(food), step in (-1,1)
            q=copy(food);q[k]+=step
            all(>=(0),q) && sum(q)<=4 || continue
            push!(result,side==1 ? (copy(give),copy(want),q,copy(wf)) : (copy(give),copy(want),copy(gf),q))
        end
        for id in ids
            q=filter(!=(id),ids)
            push!(result,side==1 ? (q,copy(want),copy(gf),copy(wf)) : (copy(give),q,copy(gf),copy(wf)))
        end
        if length(ids)<4
            for row in Iterators.take(rows,8)
                id=Int(row["ref"]);id in ids && continue
                q=vcat(ids,id)
                push!(result,side==1 ? (q,copy(want),copy(gf),copy(wf)) : (copy(give),q,copy(gf),copy(wf)))
            end
        end
    end
    unique(result)
end

function item_exchange_refine(candidates)
    groups=Dict{String,Vector{Any}}();order=String[]
    for c in candidates
        key=c["method"]
        if !haskey(groups,key);groups[key]=Any[];push!(order,key);end
        push!(groups[key],c)
    end
    [relational_best(c->get(c,"relational_field",(expected=get(c,"expected",0.),)),groups[key]).candidate for key in order]
end

function item_exchange_bind(state,features,rows;partial=false)
    available=filter(r->incidental_item_feature(r)!==nothing,collect(rows));ids=Int[]
    for f in features
        if isempty(available)
            partial && !isempty(ids) && break
            return nothing
        end
        i=argmax([incidental_item_fit(state,f,incidental_item_feature(r)) for r in available])
        push!(ids,Int(available[i]["ref"]));deleteat!(available,i)
    end
    ids
end

function item_exchange_bundle(view,ids,food)
    rows=collect(Iterators.flatten((view["own"]["held"],view["own"]["stored"],view["visible"])))
    features=Any[]
    for id in ids
        i=findfirst(r->r["ref"]==id,rows);i===nothing && return nothing
        f=incidental_item_feature(rows[i]);f===nothing && return nothing
        push!(features,f)
    end
    sort!(features;by=f->(f["color"],f["size"],f["light_source"]))
    D("items"=>features,"food"=>copy(food))
end

function item_exchange_bundle_fit(state,a,b)
    aa=unique(a["items"]);bb=unique(b["items"])
    isempty(aa)!=isempty(bb) && return 0.
    # Relation support is independent of multiplicity. Quantity is evaluated by
    # the response model and utility field after retrieval, not as mismatch.
    fit=isempty(aa) ? 1. :
        (sum(maximum(incidental_item_fit(state,f,g) for g in bb) for f in aa)/length(aa)+
         sum(maximum(incidental_item_fit(state,g,f) for f in aa) for g in bb)/length(bb))/2
    fit*exp(-sum((a["food"].>0).!=(b["food"].>0)))
end

function item_exchange_recall(state,give,want,partner,context,H)
    scored=Any[]
    for m in get(state,"exchange_relations",Any[])
        fit=item_exchange_bundle_fit(state,give,m["give"])*item_exchange_bundle_fit(state,want,m["want"])
        fit*=partner==m["partner"] ? 1. : .25
        fit*=exp(-abs(context["need"]-m["need"]))
        push!(scored,(fit=fit,m=m))
    end
    sort!(scored;by=x->(-x.fit,-x.m["successes"],x.m["key"]))
    successes=0.;failures=0.;predicted=0.
    for x in Iterators.take(scored,min(8,mb_retrieval_budget(H)))
        successes+=x.fit*x.m["successes"];failures+=x.fit*x.m["failures"]
        predicted+=x.fit*(x.m["successes"]+x.m["failures"])*item_exchange_response(x.m,give,want)
    end
    (successes=successes,failures=failures,predicted=predicted)
end

function item_exchange_learn!(state,plan,result)
    haskey(plan,"exchange_give") || return
    # Silence/expiry and physical unavailability do not establish rejection.
    status=result["status"];status in ("exchanged","declined") || return
    plan["action"]=="item_decline" && return
    give=plan["exchange_give"];want=plan["exchange_want"]
    need=plan["context"]["need"]
    item_exchange_accumulate!(item_exchange_memory!(state),give,want,plan["partner"],need,
        Int(status=="exchanged"),Int(status=="declined"),result["us"])
end

function item_exchange_option(state,feature;stock=nothing,weights=nothing)
    best=0.
    for m in get(state,"exchange_relations",Any[])
        m["successes"]>0 || continue
        # Initial option valuation supports a single tender object. Mixed/multi
        # bundles remain learnable and recallable, without attributing all their
        # proceeds to each component independently.
        length(m["give"]["items"])==1 && all(iszero,m["give"]["food"]) || continue
        fit=incidental_item_fit(state,feature,only(m["give"]["items"]))
        proceeds=sum((incidental_item_interest(f) for f in m["want"]["items"]);init=0.)
        if stock!==nothing && weights!==nothing
            proceeds+=sum(weights[k]*(log1p(stock[k]+m["want"]["food"][k])-log1p(stock[k])) for k in eachindex(stock))
        end
        confidence=m["successes"]/(2+m["successes"]+m["failures"])
        # One hop, intrinsic proceeds only: no recursive exchange-price inflation.
        best=max(best,fit*confidence*max(0.,proceeds-.002))
    end
    best
end
