# Optional possession changes use the same observable interest as pickup,
# common BasicLoop selection, and owner-local social MB predictions. No peer
# stock, hidden kind, preference or valuation is read by this policy.
function item_social_state!(state)
    get!(state,"social") do
        a=state["actor"]
        D("offer"=>BasicLoop("$a:items-offer";probabilistic=true,seed=state["loop"].seed),
          "response"=>BasicLoop("$a:items-response";probabilistic=true,seed=state["loop"].seed),
          "pending"=>nothing,"next_us"=>0,"records"=>Any[],"decisions"=>0,
          "candidates"=>0,"continued"=>0,"proposed"=>0,"accepted"=>0,"declined"=>0)
    end
end

function item_subjective_values(state,view;stock=nothing,weights=nothing)
    own=vcat(view["own"]["held"],view["own"]["stored"])
    values=Dict{Int,Float64}()
    for row in Iterators.flatten((own,view["visible"]))
        f=incidental_item_feature(row);f===nothing && continue
        values[Int(row["ref"])]=max(incidental_item_interest(f),item_exchange_option(state,f;stock,weights))
    end
    values
end

function item_social_utility(items,stock,values,weights)
    groups=Dict{String,Tuple{Int,Float64}}()
    for r in Iterators.flatten((items["held"],items["stored"]))
        f=incidental_item_feature(r);f===nothing && continue
        key=incidental_item_key(f);n,v=get(groups,key,(0,0.))
        groups[key]=(n+1,v+get(values,Int(r["ref"]),0.))
    end
    sum((v/n*log1p(n)/log(2) for (n,v) in Base.values(groups));init=0.)+
        sum(weights[k]*log1p(stock===nothing ? 0 : stock[k]) for k in eachindex(weights))
end

function item_social_actual(plan,result)
    result["status"]=="exchanged" || return 0.
    before=result["own_before"];after=result["own_after"]
    item_social_utility(after["items"],after["food"],plan["values"],plan["weights"])-
        item_social_utility(before["items"],before["food"],plan["values"],plan["weights"])+get(plan,"relation_value",0.)-.002
end

function item_social_resolve!(mind,plan,result;relation=nothing,state=nothing)
    actual=item_social_actual(plan,result);success=result["status"]=="exchanged"
    role=plan["item_social_role"]
    # Sending an offer is not acquiring anything. Only the eventual receipt
    # resolves its frozen prediction; a negative subjective outcome stays negative.
    resolve_prediction!(mind[role],plan["source"],plan["expected"],actual;
        fulfilled=success,tolerance=.01) || return false
    state!==nothing && item_exchange_learn!(state,plan,result)
    gradient_result!(relation,plan["source"],result["status"];actual,now=result["us"])

    if relation!==nothing
        social_relation_event!(relation,plan["partner"],role=="offer" ? "trade_offer" : "trade_response",
            plan["source"],result["us"];outcome=result["status"],value=actual,context=plan["context"])
    end
    item_push!(mind["records"],D("source"=>plan["source"],"partner"=>plan["partner"],
        "action"=>plan["action"],"status"=>result["status"],"expected"=>plan["expected"],
        "actual"=>actual,"subjective_gain"=>get(plan,"subjective_gain",nothing),
        "reason"=>get(result,"reason",nothing),"counter_of"=>get(plan,"counter_of",nothing),
        "exchange_evidence"=>get(plan,"exchange_evidence",nothing),
        "necessity"=>get(plan,"necessity",nothing),
        "terms"=>get(plan,"terms",nothing),"us"=>result["us"]),64)
    true
end

function item_social_observe!(state,view;relation=nothing)
    haskey(state,"social") || return
    mind=state["social"];p=mind["pending"];p===nothing && return
    for n in view["notices"]
        get(n,"offer_id",nothing)==p["offer_id"] || continue
        n["status"] in ("exchanged","declined","expired","unavailable") || continue
        item_social_resolve!(mind,p,n;relation,state);mind["pending"]=nothing;return
    end
end

function item_social_gain(own,stock,values,weights,give,want,gf,wf;visible=Any[])
    refs=Set(Int(x["ref"]) for x in Iterators.flatten((own["held"],own["stored"])))
    all(in(refs),give) && all(haskey(values,id) for id in want) || return nothing
    all(stock.>=gf) || return nothing
    rows=collect(Iterators.flatten((own["held"],own["stored"])))
    additions=filter(r->r["ref"] in want,visible)
    length(additions)==length(want) || return nothing
    after=D("held"=>vcat(filter(r->!(r["ref"] in give),rows),additions),"stored"=>Any[])
    relational_transition(item_social_utility(own,stock,values,weights),
        item_social_utility(after,stock.-gf.+wf,values,weights)).delta
end

function item_social_plan!(state,view,body,gut,stock,now;relation=nothing,require_need=true)
    view===nothing && return nothing
    body.reserve>0 && body.strain<.8 && body.damage<1 || return nothing
    mind=item_social_state!(state)
    incoming=get(view,"incoming",Any[])
    response=!isempty(incoming)
    security=food_security(relation);need=trade_food_need(body,gut,stock;security)
    if require_need && !response && need<=1e-9
        mind["need_skipped"]=get(mind,"need_skipped",0)+1
        return nothing # no recall, candidate construction, RNG or H update
    end
    (!response && (now<mind["next_us"] || mind["pending"]!==nothing || view["outgoing"]!==nothing)) && return nothing
    mind["next_us"]=now+64_000_000
    role=response ? "response" : "offer";loop=mind[role]
    loop.trial===nothing || return nothing
    item_exchange_memory!(state)
    weights=stock===nothing ? zeros(4) : food_trade_weights(body,gut)
    available=stock===nothing ? zeros(Int,4) : copy(stock)
    values=require_need && need<=1e-9 ? Dict{Int,Float64}() : item_subjective_values(state,view;stock=available,weights)
    context=D("need"=>clamp((80-body.reserve)/80,0.,1.))
    candidates=Any[]
    function candidate(other,give,want,gf,wf;offer_id=nothing,counter=false)
        stock===nothing && (any(!iszero,gf) || any(!iszero,wf)) && return
        relief=trade_food_relief(body,gut,stock,gf,wf;security)
        require_need && (need<=1e-9 || relief<=1e-9) && return
        isempty(intersect(give,want)) || return
        (!isempty(give) || !isempty(want)) && sum(gf)<=4 && sum(wf)<=4 || return
        gain=item_social_gain(view["own"],available,values,weights,give,want,gf,wf;visible=view["visible"])
        gain===nothing && return
        trace=relation===nothing ? nothing : social_relation_bias(relation,other,
            response ? "trade_response" : "trade_offer";situation=social_observed_context(relation,other,context),H=loop.H)
        relation_value=trace===nothing ? 0. : .02trace["profile"]["benefit"]
        subjective=gain+relation_value-.002
        # A valuation admissibility band, not a probability of accepting a loss.
        # Need/taste, possessions and social MB evidence remain owner-relative.
        subjective>=-.01 || return
        exchange_give=item_exchange_bundle(view,give,gf);exchange_want=item_exchange_bundle(view,want,wf)
        (exchange_give===nothing || exchange_want===nothing) && return
        evidence=item_exchange_recall(state,exchange_give,exchange_want,other,context,loop.H)
        prior=trace===nothing ? .5 : trace["profile"]["trade_probability"]
        probability=response && !counter ? 1. : (2prior+evidence.predicted)/(2+evidence.successes+evidence.failures)
        field=relational_transition(0.,gain+relation_value;probability,cost=.002)
        expected=field.expected
        # Shape-based methods generalize over object IDs. Actual refs bind only
        # the current transfer. The bounded method table is shared-loop machinery.
        action=counter ? "item_counter" : response ? "item_accept" : "item_offer"
        push!(candidates,D("method"=>"$action:$(item_exchange_key(other,exchange_give,exchange_want))",
            "action"=>action,"question"=>"subjective_possession_value",
            "components"=>D("expected"=>4expected,"relation"=>trace===nothing ? 0. : trace["weight"]),"priority"=>4expected+(trace===nothing ? 0. : trace["weight"]),
            "expected"=>expected,"gain"=>gain,"subjective_gain"=>subjective,"relation_value"=>relation_value,"partner"=>other,"trace"=>trace,
            "exchange_give"=>exchange_give,"exchange_want"=>exchange_want,
            "relational_field"=>field,
            "necessity"=>D("purpose"=>"food_security","before"=>need,"relief"=>relief,"required"=>require_need),
            "exchange_evidence"=>D("successes"=>evidence.successes,"failures"=>evidence.failures),
            "observed_context"=>social_observed_context(relation,other,context),"terms"=>D("give_items"=>copy(give),"want_items"=>copy(want),"give_food"=>copy(gf),"want_food"=>copy(wf)),
            "give_items"=>give,"want_items"=>want,"give_food"=>gf,"want_food"=>wf,"offer_id"=>offer_id))
    end
    if response
        o=first(incoming)
        candidate(o["proposer"],o["want_items"],o["give_items"],o["want_food"],o["give_food"];offer_id=o["id"])
        if isempty(candidates) && (!require_need || need>1e-9) && view["outgoing"]===nothing && mind["pending"]===nothing && get(o,"round",0)<8
            give=Int.(o["want_items"]);want=Int.(o["give_items"])
            gf=Int.(o["want_food"]);wf=Int.(o["give_food"])
            # Local changes to the received conditions. No peer warehouse lookup.
            for row in Iterators.take(view["visible"],8)
                get(row,"holder",nothing)==o["proposer"] || continue
                id=Int(row["ref"]);id in want && continue
                length(want)<4 && candidate(o["proposer"],give,vcat(want,id),gf,wf;offer_id=o["id"],counter=true)
                candidate(o["proposer"],give,[id],gf,wf;offer_id=o["id"],counter=true)
            end
            if stock!==nothing
                for k in 1:4, n in 1:(4-sum(wf))
                    more=copy(wf);more[k]+=n
                    candidate(o["proposer"],give,want,gf,more;offer_id=o["id"],counter=true)
                end
            end
            for id in give
                candidate(o["proposer"],filter(!=(id),give),want,gf,wf;offer_id=o["id"],counter=true)
            end
            for k in 1:4
                gf[k]>0 || continue
                less=copy(gf);less[k]-=1
                candidate(o["proposer"],give,want,less,wf;offer_id=o["id"],counter=true)
            end
            if !isempty(candidates)
                candidates=item_exchange_refine(candidates)
                sort!(candidates;by=c->(-c["expected"],c["method"]))
                length(candidates)>32 && resize!(candidates,32)
                for c in candidates;c["observation_log_prior"]=-log(length(candidates));end
            end
        end
        push!(candidates,D("method"=>"decline:$(o["proposer"])","action"=>"item_decline",
            "question"=>"subjective_possession_value","priority"=>0.,"expected"=>0.,
            "offer_id"=>o["id"],"partner"=>o["proposer"],"trace"=>nothing))
    else
        own=Iterators.take(view["own"]["held"],4)
        if require_need && stock!==nothing
            # Tender a possession for needed food without inspecting peer stock.
            for other in get(view,"trade_partners",String[]), held in own, k in eachindex(available), n in 1:4
                wf=zeros(Int,4);wf[k]=n
                candidate(other,[Int(held["ref"])],Int[],zeros(Int,4),wf)
            end
        end
        # Recall previously successful bundles, binding their features to things
        # currently owned/visible. This also permits learned item-for-food offers.
        memories=sort(collect(get(state,"exchange_relations",Any[]));by=m->(-m["successes"],-m["last_us"],m["key"]))
        for m in Iterators.take(filter(m->m["successes"]>0,memories),min(8,mb_retrieval_budget(loop.H))), other in get(view,"trade_partners",String[])
            give=item_exchange_bind(state,m["give"]["items"],view["own"]["held"];partial=true)
            want=item_exchange_bind(state,m["want"]["items"],filter(r->get(r,"holder",nothing)==other,view["visible"]);partial=true)
            (give===nothing || want===nothing) && continue
            for terms in item_exchange_neighbors(give,want,m["give"]["food"],m["want"]["food"],
                view["own"]["held"],filter(r->get(r,"holder",nothing)==other,view["visible"]))
                candidate(other,terms...)
            end
        end
        # Only currently visible possessions of a contact partner can be requested.
        for r in Iterators.take(view["visible"],8)
            other=get(r,"holder",nothing)
            other in get(view,"trade_partners",String[]) || continue
            candidate(other,Int[],[Int(r["ref"])],zeros(Int,4),zeros(Int,4))
            for held in own
                candidate(other,[Int(held["ref"])],[Int(r["ref"])],zeros(Int,4),zeros(Int,4))
            end
            for k in eachindex(available), n in 1:min(4,available[k])
                available[k]>0 || continue
                gf=zeros(Int,4);gf[k]=n
                candidate(other,Int[],[Int(r["ref"])],gf,zeros(Int,4))
            end
        end
        # Gift proposals use the same recipient acceptance and valuation route.
        for other in get(view,"trade_partners",String[]), held in own
            candidate(other,[Int(held["ref"])],Int[],zeros(Int,4),zeros(Int,4))
        end
        # Refine feasible seed offers locally, just as movement refines heading.
        for seed in Iterators.take(copy(candidates),32)
            other=seed["partner"]
            for terms in item_exchange_neighbors(seed["give_items"],seed["want_items"],seed["give_food"],seed["want_food"],
                view["own"]["held"],filter(r->get(r,"holder",nothing)==other,view["visible"]))
                candidate(other,terms...)
            end
        end
        isempty(candidates) && return nothing
        candidates=item_exchange_refine(candidates)
        sort!(candidates;by=c->(-c["expected"],c["method"]))
        length(candidates)>32 && resize!(candidates,32)
        for c in candidates;c["observation_log_prior"]=-log(length(candidates));end
        push!(candidates,D("method"=>"continue_activity","action"=>"continue","priority"=>.5,
            "observation_log_prior"=>4context["need"],"question"=>"continue_parent_activity"))
    end
    # Equivalent edits (e.g. append vs replace an empty requested list) and
    # visually equivalent objects are one MB method, not extra lottery tickets.
    candidates=item_exchange_refine(candidates)
    proposals=count(c->c["action"] in ("item_offer","item_counter"),candidates)
    for c in candidates
        c["action"] in ("item_offer","item_counter") && (c["observation_log_prior"]=-log(proposals))
    end
    incidental_item_bound_methods!(D("loop"=>loop),candidates)
    source="items:$role:$(state["actor"]):$now"
    plan=choose_method!(loop,candidates,source)
    gradient_capture!(relation,loop,candidates,plan,source,now;channel="item_trade")
    mind["decisions"]+=1;mind["candidates"]+=length(candidates)
    if plan["action"]=="continue"
        gradient_result!(relation,source,"continued";now)
        mind["continued"]+=1
        resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
        return nothing
    end
    evidence=get(plan,"exchange_evidence",nothing)
    if evidence!==nothing && evidence["successes"]>0
        state["exchange_recalled_choices"]=get(state,"exchange_recalled_choices",0)+1
    end
    merge!(plan,D("item_social_role"=>role,"source"=>source,"values"=>values,
        "weights"=>weights,"context"=>get(plan,"observed_context",context),"portable_item_action"=>true))
    if plan["action"] in ("item_offer","item_counter")
        plan["target"]=plan["partner"]
        plan["action"]=="item_offer" && delete!(plan,"offer_id")
    else
        for k in ("give_items","want_items","give_food","want_food");pop!(plan,k,nothing);end
    end

    if relation!==nothing && plan["trace"]!==nothing
        social_relation_use!(relation,plan["partner"],response ? "trade_response" : "trade_offer",
            source,now,plan["trace"];action=plan["action"])
    end
    plan
end

function item_social_executed!(state,plan,result;relation=nothing)
    mind=state["social"]
    if result["status"]=="offered"
        mind["pending"]!==nothing && mind["pending"]["offer_id"]==result["offer_id"] && return false
        mind["pending"]=merge(deepcopy(plan),D("offer_id"=>result["offer_id"],
            "counter_of"=>plan["action"]=="item_counter" ? plan["offer_id"] : nothing))
        gradient_result!(relation,plan["source"],"offered";now=result["us"])
        mind["proposed"]+=1
        plan["action"]=="item_counter" && (mind["counterproposed"]=get(mind,"counterproposed",0)+1)
    else
        item_social_resolve!(mind,plan,result;relation,state) || return false
        result["status"]=="exchanged" && (mind["accepted"]+=1)
        result["status"]=="declined" && (mind["declined"]+=1)
    end
    true
end
function item_social_snapshot(mind)
    D("offer"=>loop_snapshot(mind["offer"]),"response"=>loop_snapshot(mind["response"]),
        "need_skipped"=>get(mind,"need_skipped",0),
        "pending"=>deepcopy(mind["pending"]),"records"=>deepcopy(mind["records"]),"counterproposed"=>get(mind,"counterproposed",0),
        (k=>mind[k] for k in ("decisions","candidates","continued","proposed","accepted","declined"))...)
end
