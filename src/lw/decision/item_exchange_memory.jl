# Observer-owned, bounded relations between observed bundles. References bind
# execution only; prototypes contain features and stated food quantities.
item_exchange_memory!(state)=get!(state,"exchange_relations",Any[])

function item_exchange_bind(state,features,rows)
    available=filter(r->incidental_item_feature(r)!==nothing,collect(rows));ids=Int[]
    for f in features
        isempty(available) && return nothing
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
    length(a["items"])==length(b["items"]) || return 0.
    # Tiny bundles (<=4); a one-to-one match prevents counting one object twice.
    remaining=collect(eachindex(b["items"]));fit=1.
    for f in a["items"]
        scores=[incidental_item_fit(state,f,b["items"][j]) for j in remaining]
        i=argmax(scores);fit*=scores[i];deleteat!(remaining,i)
    end
    fit*exp(-sum(abs.(a["food"].-b["food"])))
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
    successes=0.;failures=0.
    for x in Iterators.take(scored,min(8,mb_retrieval_budget(H)))
        successes+=x.fit*x.m["successes"];failures+=x.fit*x.m["failures"]
    end
    (successes=successes,failures=failures)
end

function item_exchange_learn!(state,plan,result)
    haskey(plan,"exchange_give") || return
    # Silence/expiry and physical unavailability do not establish rejection.
    status=result["status"];status in ("exchanged","declined") || return
    plan["action"]=="item_decline" && return
    give=plan["exchange_give"];want=plan["exchange_want"]
    need=plan["context"]["need"]
    key=repr((plan["partner"],give["items"],give["food"],want["items"],want["food"],floor(Int,4need)))
    memory=item_exchange_memory!(state);i=findfirst(m->m["key"]==key,memory)
    if i===nothing
        if length(memory)>=128
            deleteat!(memory,argmin([(m["successes"]>0,m["last_us"]) for m in memory]))
        end
        push!(memory,D("key"=>key,"partner"=>plan["partner"],"give"=>deepcopy(give),
            "want"=>deepcopy(want),"need"=>need,"successes"=>0,"failures"=>0,"last_us"=>result["us"]))
        i=length(memory)
    end
    m=memory[i];m[status=="exchanged" ? "successes" : "failures"]+=1;m["last_us"]=result["us"]
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
