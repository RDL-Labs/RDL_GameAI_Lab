# Authoritative camp transactions. Beliefs, utilities and offer selection live
# outside this module; another owner's warehouse is never included in a view.
const FOOD_EXCHANGE_TTL_US=30_000_000

function food_exchange_state()
    D("offers"=>D(),"receipts"=>D(),"clock_us"=>-1,
        "notices"=>D(a=>Any[] for a in IDS),"records"=>Any[],
        "counts"=>D(k=>0 for k in ("offered","exchanged","declined","expired","unavailable")))
end

function food_exchange_time(now)
    check(now isa Integer && !(now isa Bool) && 0<=now<=typemax(Int)-FOOD_EXCHANGE_TTL_US,"trade_time")
    Int(now)
end
food_exchange_at_home(w,home,a)=hypot(w.positions[a][1]-home[1],w.positions[a][2]-home[2])<=1.25
food_exchange_contact(w,home,a,b)=b in IDS && b!=a &&
    food_exchange_at_home(w,home,a) && food_exchange_at_home(w,home,b) &&
    contact(w,a,b) && w.hearing[a] && w.hearing[b]

function food_exchange_record!(s,offer,status,now)
    event=merge(deepcopy(offer),D("offer_id"=>offer["id"],"status"=>status,"us"=>now))
    push!(s["records"],event)
    length(s["records"])>64 && popfirst!(s["records"])
    s["counts"][status]+=1
    event
end

function food_exchange_close!(s,offer,status,now;changes=nothing)
    delete!(s["offers"],offer["id"])
    event=food_exchange_record!(s,offer,status,now)
    for a in (offer["proposer"],offer["target"])
        notice=deepcopy(event)
        if changes!==nothing
            # A party observes its own transaction result, never the other
            # warehouse. Observer records keep only public offer terms.
            notice["own_before"]=copy(changes[a].before)
            notice["own_after"]=copy(changes[a].after)
        end
        push!(s["notices"][a],notice)
        length(s["notices"][a])>32 && popfirst!(s["notices"][a])
    end
    event
end

function food_exchange_expire!(s,now)
    t=food_exchange_time(now)
    check(t>=s["clock_us"],"trade_clock_rewind")
    s["clock_us"]=t
    # Sort IDs so simultaneous expiry has stable notification order.
    expired=sort([id for (id,o) in s["offers"] if t>=o["expires_us"]])
    for id in expired
        food_exchange_close!(s,s["offers"][id],"expired",t)
    end
    nothing
end

function food_exchange_view(s,r,w,home,a,now)
    check(a in IDS,"trade_actor")
    t=food_exchange_time(now)
    partners=String[b for b in IDS if food_exchange_contact(w,home,a,b)]
    incoming=Any[deepcopy(o) for (_,o) in sort(collect(s["offers"]);by=first)
        if o["target"]==a && t<o["expires_us"] && o["proposer"] in partners]
    outgoing=findfirst(id->begin
        o=s["offers"][id];o["proposer"]==a && t<o["expires_us"]
    end,sort(collect(keys(s["offers"]))))
    ids=sort(collect(keys(s["offers"])))
    D("own_stock"=>copy(r.personal[a]),"partners"=>partners,"incoming"=>incoming,
        "outgoing"=>outgoing===nothing ? nothing : ids[outgoing],
        "notices"=>deepcopy(s["notices"][a]))
end

function food_exchange_execute!(s,r,w,stores,home,a,op,action,now;
        target=nothing,offer_id=nothing,give_kind=0,give_count=0,want_kind=0,want_count=0)
    check(a in IDS && op isa AbstractString && !isempty(op),"trade_identity")
    check(action in ("trade_offer","trade_accept","trade_decline"),"trade_action")
    t=food_exchange_time(now)
    # Validate even a replay: numerical equality alone would equate 1 with
    # true or 1.0 and bypass the integer resource protocol.
    if action=="trade_offer"
        check(target in IDS && target!=a && offer_id===nothing,"trade_target")
        check(all(k->k isa Integer && !(k isa Bool) && k in RDLBody.FOOD_KIND_IDS,(give_kind,want_kind)),"trade_kind")
        check(give_kind!=want_kind,"trade_same_kind")
        check(all(n->n isa Integer && !(n isa Bool) && 1<=n<=4,(give_count,want_count)),"trade_quantity")
    else
        check(offer_id isa AbstractString && !isempty(offer_id),"trade_offer_id")
        check(target===nothing && (give_kind,give_count,want_kind,want_count)==(0,0,0,0),"trade_reply_terms")
    end
    signature=(action,target,offer_id,give_kind,give_count,want_kind,want_count)
    previous=get(s["receipts"],a,nothing)
    # Operation identity is (actor, execution time, op). Replays retain the
    # original time; one operation per actor per tick permits bounded receipts.
    if previous!==nothing && t==previous["us"]
        check(previous["op"]==op && previous["signature"]==signature,"trade_operation_conflict")
        return deepcopy(previous["result"])
    end
    check(previous===nothing || t>previous["us"],"trade_stale_operation")
    check(t>=s["clock_us"],"trade_clock_rewind")
    food_exchange_expire!(s,t)
    status="unavailable";id=offer_id;reason="unknown_offer"
    own_before=nothing;own_after=nothing
    if action=="trade_offer"
        occupied=any(o->o["proposer"]==a,values(s["offers"]))
        if occupied
            reason="outgoing_pending"
        elseif !food_exchange_contact(w,home,a,target)
            reason="partner_unavailable"
        elseif r.personal[a][give_kind]<give_count
            reason="stock_unavailable"
        else
            # No reservation and no read of the partner's warehouse here.
            id="$a:$t:$op"
            offer=D("id"=>id,"proposer"=>a,"target"=>target,
                "give_kind"=>Int(give_kind),"give_count"=>Int(give_count),
                "want_kind"=>Int(want_kind),"want_count"=>Int(want_count),
                "created_us"=>t,"expires_us"=>t+FOOD_EXCHANGE_TTL_US)
            s["offers"][id]=offer
            food_exchange_record!(s,offer,"offered",t)
            status="offered";reason=nothing
        end
    elseif haskey(s["offers"],id)
        offer=s["offers"][id];proposer=offer["proposer"]
        if offer["target"]!=a
            reason="not_recipient" # An outsider must not close another pair's offer.
        elseif !food_exchange_contact(w,home,a,proposer)
            reason="partner_unavailable"
            food_exchange_close!(s,offer,status,t)
        elseif action=="trade_decline"
            status="declined";reason=nothing
            food_exchange_close!(s,offer,status,t)
        else
            g,n,h,m=offer["give_kind"],offer["give_count"],offer["want_kind"],offer["want_count"]
            if r.personal[proposer][g]<n || r.personal[a][h]<m
                reason="stock_unavailable"
                food_exchange_close!(s,offer,status,t)
            else
                # Validate every resource change before mutating either owner.
                left=copy(r.personal[proposer]);right=copy(r.personal[a])
                check(sum(left)==stores[proposer] && sum(right)==stores[a],"trade_storage_mismatch")
                proposer_before=copy(left);own_before=copy(right)
                left[g]-=n;left[h]+=m;right[h]-=m;right[g]+=n
                check(all(>=(0),left) && all(>=(0),right),"trade_stock")
                left_total=sum(left);right_total=sum(right)
                r.personal[proposer].=left;r.personal[a].=right
                stores[proposer]=left_total;stores[a]=right_total
                status="exchanged";reason=nothing
                own_after=copy(right)
                changes=Dict(proposer=>(before=proposer_before,after=left),a=>(before=own_before,after=right))
                food_exchange_close!(s,offer,status,t;changes=changes)
            end
        end
    end
    # A failed initial offer/reply may not correspond to a closeable proposal.
    # Count it as an attempt, without generating another terminal notice.
    if status=="unavailable" && (action=="trade_offer" || reason in ("unknown_offer","not_recipient"))
        s["counts"]["unavailable"]+=1
    end
    result=D("actor"=>a,"operation"=>String(op),"action"=>action,"us"=>t,
        "status"=>status,"offer_id"=>id,"reason"=>reason)
    if status=="exchanged"
        result["own_before"]=own_before;result["own_after"]=own_after
    end
    s["receipts"][a]=D("op"=>String(op),"us"=>t,"signature"=>signature,"result"=>deepcopy(result))
    result
end

food_exchange_snapshot(s)=D("rule"=>"camp-personal-food-exchange-v1",
    "counts"=>copy(s["counts"]),"active"=>[deepcopy(o) for (_,o) in sort(collect(s["offers"]);by=first)],
    "records"=>deepcopy(s["records"]))
