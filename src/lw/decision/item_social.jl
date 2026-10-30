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

function item_subjective_values(state,view)
    own=vcat(view["own"]["held"],view["own"]["stored"])
    values=Dict{Int,Float64}()
    for row in Iterators.flatten((own,view["visible"]))
        f=incidental_item_feature(row);f===nothing && continue
        # Similar possessions reduce marginal interest. IDs exclude the current
        # executor object only; similarity and interest use observable features.
        similar=0.
        for held in own
            held["ref"]==row["ref"] && continue
            g=incidental_item_feature(held);g===nothing && continue
            similar+=incidental_item_fit(state,f,g)
        end
        values[Int(row["ref"])]=incidental_item_interest(f)/(1+similar)
    end
    values
end

item_social_utility(items,stock,values,weights)=
    sum((get(values,Int(r["ref"]),0.) for r in Iterators.flatten((items["held"],items["stored"])));init=0.)+
    sum(weights[k]*log1p(stock===nothing ? 0 : stock[k]) for k in eachindex(weights))

function item_social_actual(plan,result)
    result["status"]=="exchanged" || return 0.
    before=result["own_before"];after=result["own_after"]
    item_social_utility(after["items"],after["food"],plan["values"],plan["weights"])-
        item_social_utility(before["items"],before["food"],plan["values"],plan["weights"])+get(plan,"relation_value",0.)-.002
end

function item_social_resolve!(mind,plan,result;relation=nothing)
    actual=item_social_actual(plan,result);success=result["status"]=="exchanged"
    role=plan["item_social_role"]
    # Sending an offer is not acquiring anything. Only the eventual receipt
    # resolves its frozen prediction; a negative subjective outcome stays negative.
    resolve_prediction!(mind[role],plan["source"],plan["expected"],actual;
        fulfilled=success,tolerance=.01) || return false
    if relation!==nothing
        social_relation_event!(relation,plan["partner"],role=="offer" ? "trade_offer" : "trade_response",
            plan["source"],result["us"];outcome=result["status"],value=actual,context=plan["context"])
    end
    item_push!(mind["records"],D("source"=>plan["source"],"partner"=>plan["partner"],
        "action"=>plan["action"],"status"=>result["status"],"expected"=>plan["expected"],
        "actual"=>actual,"subjective_gain"=>get(plan,"subjective_gain",nothing),
        "reason"=>get(result,"reason",nothing),"counter_of"=>get(plan,"counter_of",nothing),
        "terms"=>get(plan,"terms",nothing),"us"=>result["us"]),64)
    true
end

function item_social_observe!(state,view;relation=nothing)
    haskey(state,"social") || return
    mind=state["social"];p=mind["pending"];p===nothing && return
    for n in view["notices"]
        get(n,"offer_id",nothing)==p["offer_id"] || continue
        n["status"] in ("exchanged","declined","expired","unavailable") || continue
        item_social_resolve!(mind,p,n;relation);mind["pending"]=nothing;return
    end
end

function item_social_gain(own,stock,values,weights,give,want,gf,wf)
    refs=Set(Int(x["ref"]) for x in Iterators.flatten((own["held"],own["stored"])))
    all(in(refs),give) && all(haskey(values,id) for id in want) || return nothing
    all(stock.>=gf) || return nothing
    sum((values[id] for id in want);init=0.)-sum((values[id] for id in give);init=0.)+
        sum(weights[k]*(log1p(stock[k]-gf[k]+wf[k])-log1p(stock[k])) for k in eachindex(stock))
end

function item_social_plan!(state,view,body,gut,stock,now;relation=nothing)
    view===nothing && return nothing
    body.reserve>0 && body.strain<.8 && body.damage<1 || return nothing
    mind=item_social_state!(state)
    incoming=get(view,"incoming",Any[])
    response=!isempty(incoming)
    (!response && (now<mind["next_us"] || mind["pending"]!==nothing || view["outgoing"]!==nothing)) && return nothing
    mind["next_us"]=now+64_000_000
    role=response ? "response" : "offer";loop=mind[role]
    loop.trial===nothing || return nothing
    values=item_subjective_values(state,view)
    weights=stock===nothing ? zeros(4) : food_trade_weights(body,gut)
    available=stock===nothing ? zeros(Int,4) : copy(stock)
    context=D("need"=>clamp((80-body.reserve)/80,0.,1.))
    candidates=Any[]
    function candidate(other,give,want,gf,wf;offer_id=nothing,counter=false)
        isempty(intersect(give,want)) || return
        (!isempty(give) || !isempty(want)) && sum(gf)<=4 && sum(wf)<=4 || return
        gain=item_social_gain(view["own"],available,values,weights,give,want,gf,wf)
        gain===nothing && return
        trace=relation===nothing ? nothing : social_relation_bias(relation,other,
            response ? "trade_response" : "trade_offer";situation=context,H=loop.H)
        relation_value=trace===nothing ? 0. : .02trace["profile"]["benefit"]
        subjective=gain+relation_value-.002
        # A valuation admissibility band, not a probability of accepting a loss.
        # Need/taste, possessions and social MB evidence remain owner-relative.
        subjective>=-.01 || return
        probability=response && !counter ? 1. : trace===nothing ? .5 : trace["profile"]["trade_probability"]
        expected=probability*subjective
        # Shape-based methods generalize over object IDs. Actual refs bind only
        # the current transfer. The bounded method table is shared-loop machinery.
        shape(ids)=join(sort([incidental_item_key(incidental_item_feature(r)) for r in
            Iterators.flatten((view["own"]["held"],view["own"]["stored"],view["visible"]))
            if r["ref"] in ids]),"|")
        action=counter ? "item_counter" : response ? "item_accept" : "item_offer"
        push!(candidates,D("method"=>"$action:$other:$(shape(give)):$(shape(want)):$gf:$wf",
            "action"=>action,"question"=>"subjective_possession_value",
            "priority"=>4expected+(trace===nothing ? 0. : trace["weight"]),
            "expected"=>expected,"gain"=>gain,"subjective_gain"=>subjective,"relation_value"=>relation_value,"partner"=>other,"trace"=>trace,
            "terms"=>D("give_items"=>copy(give),"want_items"=>copy(want),"give_food"=>copy(gf),"want_food"=>copy(wf)),
            "give_items"=>give,"want_items"=>want,"give_food"=>gf,"want_food"=>wf,"offer_id"=>offer_id))
    end
    if response
        o=first(incoming)
        candidate(o["proposer"],o["want_items"],o["give_items"],o["want_food"],o["give_food"];offer_id=o["id"])
        if isempty(candidates) && view["outgoing"]===nothing && mind["pending"]===nothing && get(o,"round",0)<8
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
        # Only currently visible possessions of a contact partner can be requested.
        for r in Iterators.take(view["visible"],8)
            other=get(r,"holder",nothing)
            other in get(view,"trade_partners",String[]) || continue
            candidate(other,Int[],[Int(r["ref"])],zeros(Int,4),zeros(Int,4))
            for held in own
                candidate(other,[Int(held["ref"])],[Int(r["ref"])],zeros(Int,4),zeros(Int,4))
            end
            for k in eachindex(available)
                available[k]>0 || continue
                gf=zeros(Int,4);gf[k]=1
                candidate(other,Int[],[Int(r["ref"])],gf,zeros(Int,4))
            end
        end
        # Gift proposals use the same recipient acceptance and valuation route.
        for other in get(view,"trade_partners",String[]), held in own
            candidate(other,[Int(held["ref"])],Int[],zeros(Int,4),zeros(Int,4))
        end
        isempty(candidates) && return nothing
        sort!(candidates;by=c->(-c["expected"],c["method"]))
        length(candidates)>32 && resize!(candidates,32)
        for c in candidates;c["observation_log_prior"]=-log(length(candidates));end
        push!(candidates,D("method"=>"continue_activity","action"=>"continue","priority"=>.5,
            "observation_log_prior"=>4context["need"],"question"=>"continue_parent_activity"))
    end
    # Equivalent edits (e.g. append vs replace an empty requested list) and
    # visually equivalent objects are one MB method, not extra lottery tickets.
    unique!(c->c["method"],candidates)
    proposals=count(c->c["action"] in ("item_offer","item_counter"),candidates)
    for c in candidates
        c["action"] in ("item_offer","item_counter") && (c["observation_log_prior"]=-log(proposals))
    end
    incidental_item_bound_methods!(D("loop"=>loop),candidates)
    source="items:$role:$(state["actor"]):$now"
    plan=choose_method!(loop,candidates,source)
    mind["decisions"]+=1;mind["candidates"]+=length(candidates)
    if plan["action"]=="continue"
        mind["continued"]+=1
        resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
        return nothing
    end
    merge!(plan,D("item_social_role"=>role,"source"=>source,"values"=>values,
        "weights"=>weights,"context"=>context,"portable_item_action"=>true))
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
        mind["proposed"]+=1
        plan["action"]=="item_counter" && (mind["counterproposed"]=get(mind,"counterproposed",0)+1)
    else
        item_social_resolve!(mind,plan,result;relation) || return false
        result["status"]=="exchanged" && (mind["accepted"]+=1)
        result["status"]=="declined" && (mind["declined"]+=1)
    end
    true
end
function item_social_snapshot(mind)
    D("offer"=>loop_snapshot(mind["offer"]),"response"=>loop_snapshot(mind["response"]),
        "pending"=>deepcopy(mind["pending"]),"records"=>deepcopy(mind["records"]),"counterproposed"=>get(mind,"counterproposed",0),
        (k=>mind[k] for k in ("decisions","candidates","continued","proposed","accepted","declined"))...)
end
