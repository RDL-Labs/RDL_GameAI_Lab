# 暫定固定: scene.camp_trade_calls=false. Whole-camp semantic announcements,
# known voice/identity, one call/day and a central meeting point are shortcuts.
# No lexicon learning or warehouse observation is supplied by this adapter.
# Future: learned speech, recognition, attention and meeting-place MBs.
# State lives inside incidental_items and is serialized by existing checkpoints.
const CAMP_TRADE_CALL_RULES=(lifetime_us=128_000_000,records=128,offered_quantity=1)
function configured_camp_trade_state!(state)
    get!(() -> D("last_day"=>-1,"outgoing"=>nothing,"meeting"=>nothing,
        "calls"=>0,"heard"=>0,"replied"=>0,"ignored"=>0,"sleep_ignored"=>0,
        "expired"=>0,"negotiated"=>0,"address_H"=>D(),"records"=>Any[]),state,"camp_trade")
end
function configured_camp_trade_record!(state,event,now;kwargs...)
    totals=get!(()->D(),configured_camp_trade_state!(state),"event_counts")
    totals[event]=get(totals,event,0)+1
    records=configured_camp_trade_state!(state)["records"]
    push!(records,D("event"=>event,"us"=>now,(string(k)=>v for (k,v) in kwargs)...))
    length(records)>CAMP_TRADE_CALL_RULES.records && popfirst!(records)
end
function configured_camp_trade_address!(state,kind,now)
    # Peers are retrieved from successful exchanges, not the world's actor list.
    peers=unique([m["partner"] for m in get(state,"exchange_relations",Any[])])
    support=item_exchange_supplier_support(state,kind,peers)
    residual=configured_camp_trade_state!(state)["address_H"]
    loop=get!(() -> BasicLoop(state["actor"]*":camp-address";probabilistic=true,seed=state["loop"].seed),state,"camp_address_loop")
    candidates=Any[D("method"=>"broadcast","priority"=>0.,"question"=>"communication_opportunity")]
    append!(candidates,[D("method"=>peer,"priority"=>support[peer]-get(residual,"$kind:$peer",0.),"question"=>"communication_opportunity") for peer in sort!(collect(keys(support)))])
    probabilities=method_distribution(loop,candidates)
    source="camp-address:$(state["actor"]):$now"
    plan=choose_method!(loop,candidates,source)
    resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
    (peer=plan["method"]=="broadcast" ? nothing : plan["method"],support=support,
        probabilities=D(c["method"]=>probabilities[i] for (i,c) in enumerate(candidates)))
end
function configured_camp_trade_call!(state,map,body,gut,stock,now,day_us;kitchen=nothing,relation=nothing,allow_start=true,processing_requests=false,items=nothing,surplus_calls=false)
    channel=configured_camp_trade_state!(state)
    opportunity_enabled=configured_trade_opportunity_enabled(state)
    allow_start && (opportunity_enabled || channel["last_day"]!=div(now,day_us)) && channel["outgoing"]===nothing && channel["meeting"]===nothing || return nothing
    desire=trade_request_desire(body,gut,stock;map,kitchen,relation)
    if surplus_calls || opportunity_enabled
        rows=surplus_calls ? configured_surplus_candidates(map,body,gut,stock;relation) : Any[]
        choices=Any[D("method"=>"hold","priority"=>0.)]
        desire!==nothing && push!(choices,D("method"=>"buy","priority"=>desire.gradient["total"]))
        append!(choices,[D("method"=>"sell:$i","priority"=>row["gradient"]["total"]) for (i,row) in enumerate(rows)])
        if opportunity_enabled
            for choice in choices
                choice["method"]=="hold" && continue
                sale=startswith(choice["method"],"sell:")
                kind=sale ? rows[parse(Int,split(choice["method"],":")[2])]["kind"] : desire.kind
                choice["opportunity_key"]="$(sale ? "sell" : "buy"):$kind"
                choice["benefit"]=choice["priority"]
                choice["priority"]=configured_trade_opportunity_score(state,choice["opportunity_key"],choice["benefit"]).priority
            end
            # 成果見込みが手間・未解消差を超えないものは開始動機にならない。
            filter!(c->c["method"]=="hold" || c["priority"]>0.,choices)
        end
        for choice in choices;choice["question"]="communication_opportunity";end
        loop=get!(() -> BasicLoop(state["actor"]*":camp-intent";probabilistic=true,seed=state["loop"].seed),state,"camp_intent_loop")
        source="camp-intent:$(state["actor"]):$now"
        selected=choose_method!(loop,choices,source)
        resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
        channel["last_day"]=div(now,day_us)
        if selected["method"]=="hold"
            opportunity_enabled && (state["trade_opportunity"]["ready_home"]=true)
            configured_camp_trade_record!(state,"call_skipped",now)
            return nothing
        elseif startswith(selected["method"],"sell:")
            row=rows[parse(Int,split(selected["method"],":")[2])]
            event=D("id"=>source,"caller"=>state["actor"],"direction"=>"sell","kind"=>row["kind"],"row"=>row,
                "offered"=>Dict(row["kind"]=>row["quantity"]),"created_us"=>now,"expires_us"=>now+CAMP_TRADE_CALL_RULES.lifetime_us,
                "addressee"=>nothing,"expected_reply"=>0.,"heard"=>Set{String}(),"replies"=>Any[])
            channel["outgoing"]=event;channel["calls"]+=1
            opportunity_enabled && configured_trade_opportunity_begin!(state,"sell:$(row["kind"])",row["gradient"]["total"],event)
            configured_camp_trade_record!(state,"sell_call",now;kind=row["kind"],quantity=row["quantity"],gradient=row["gradient"])
            return event
        end
    end
    desire===nothing && return nothing
    security=get(map,"food_security",food_security(relation))
    need=trade_food_need(body,gut,stock;security)
    offered=Dict{Int,Int}()
    for kind in trade_request_recall(map)
        kind==desire.kind && continue
        stock[kind]>0 || continue
        after=copy(stock);after[kind]-=CAMP_TRADE_CALL_RULES.offered_quantity
        trade_food_need(body,gut,after;security)<=need && (offered[kind]=CAMP_TRADE_CALL_RULES.offered_quantity)
    end
    address=configured_camp_trade_address!(state,desire.kind,now)
    event=D("id"=>"camp-call:$(state["actor"]):$now","caller"=>state["actor"],"kind"=>desire.kind,
        "offered"=>offered,"created_us"=>now,"expires_us"=>now+CAMP_TRADE_CALL_RULES.lifetime_us,
        "addressee"=>address.peer,"expected_reply"=>address.peer===nothing ? 0. : address.support[address.peer]/(1+address.support[address.peer]),"heard"=>Set{String}(),"replies"=>Any[])
    # Public conditional request: "I can cook ingredient X myself". No peer read.
    processing_requests && (event["processing_inputs"]=trade_request_processing_inputs(map,body,gut,kitchen,desire.kind;items))
    channel["last_day"]=div(now,day_us);channel["outgoing"]=event;channel["calls"]+=1
    opportunity_enabled && configured_trade_opportunity_begin!(state,"buy:$(desire.kind)",desire.gradient["total"],event)
    configured_camp_trade_record!(state,"call",now;kind=desire.kind,offered=copy(offered),addressee=address.peer,
        gradient=desire.gradient,support=address.support,probabilities=address.probabilities)
    event
end
function configured_camp_trade_interest(event,state,map,body,gut,stock,now;kitchen=nothing,relation=nothing,processing_requests=false,items=nothing,open_terms=false)
    kind=event["kind"]
    kind in trade_request_recall(map) || return nothing
    supplies=Any[]
    stock[kind]>0 && push!(supplies,D("input"=>kind,"output"=>kind,"mode"=>"direct","cost"=>0.))
    if processing_requests
        for input in trade_request_recall(map)
            input!=kind && stock[input]>0 || continue
            advertised=get(get(event,"processing_inputs",Dict{Int,Any}()),input,nothing)
            advertised!==nothing && advertised["output"]==kind && push!(supplies,D("input"=>input,"output"=>kind,"mode"=>"recipient_processing","cost"=>0.))
            forecast=trade_request_processing(map,body,gut,kitchen,input,kind;items)
            forecast===nothing || push!(supplies,merge(forecast,D("mode"=>"supplier_processing")))
        end
    end
    isempty(supplies) && return nothing
    # 暫定固定・局所実験のみ(open_terms=false): direct owned supply permits
    # discussion without payment. This is not consent or a transfer; ordinary
    # negotiation must still evaluate both sides. Future: learned willingness.
    # Unpaid preparation is excluded until its own consent is modelled.
    if open_terms && isempty(event["offered"])
        direct=findfirst(s->s["mode"]=="direct",supplies)
        direct===nothing && return nothing
        return (wanted=nothing,gradient=D("total"=>0.,"stage"=>"terms_pending"),supply=supplies[direct])
    end
    security=get(map,"food_security",food_security(relation))
    context=social_observed_context(relation,event["caller"],D("need"=>body_demand(body)))
    trace=relation===nothing ? nothing : social_relation_bias(relation,event["caller"],"trade_offer";situation=context,H=0.)
    valuation=trade_valuation_context(body,gut,security,context,trace)
    weights=food_trade_weights(body,gut;map,kitchen)
    best=nothing
    # The caller disclosed only these possible payments, not their whole stock.
    for supply in supplies, wanted in sort!(collect(keys(event["offered"])))
        wanted in trade_request_recall(map) || continue
        after=copy(stock);after[supply["input"]]-=1;after[wanted]+=1
        material=sum(weights[k]*(log1p(after[k])-log1p(stock[k])) for k in eachindex(stock))
        gradient=trade_compound_gradient(stock,after,material,valuation)
        if supply["cost"]>0
            gradient["processing_cost"]=-supply["cost"];gradient["total"]-=supply["cost"]
        end
        gradient["total"]>0 || continue
        (best===nothing || gradient["total"]>best.gradient["total"]) && (best=(wanted=wanted,gradient=gradient,supply=supply))
    end
    best
end
configured_camp_trade_busy(state)=state!==nothing && haskey(state,"camp_trade") &&
    (state["camp_trade"]["outgoing"]!==nothing || state["camp_trade"]["meeting"]!==nothing)
function configured_camp_trade_working(map)
    focus=get(map,"task_focus",D())
    get(focus,"active",false) && get(get(focus,"plan",D()),"action",nothing) in ("fish","process_food")
end
function configured_camp_trade_tick!(states,maps,world,foods,guts,relations,now,in_camp,sleeping,busy;kitchen_for=a->nothing,processing_requests=false,items=nothing,open_terms=false)
    # Snapshot delivery before any current-tick actions; callers' newly created
    # announcements are heard on the next tick regardless of actor iteration order.
    for actor in sort!(collect(keys(states)))
        channel=configured_camp_trade_state!(states[actor])
        for key in ("meeting","outgoing")
            pending=channel[key]
            pending===nothing && continue
            if now>=pending["expires_us"]
                configured_trade_opportunity_finish!(states[actor],false,now;reason="expired_$key")
                if key=="outgoing" && pending["addressee"]!==nothing
                    address_key="$(pending["kind"]):$(pending["addressee"])"
                    channel["address_H"][address_key]=get(channel["address_H"],address_key,0.)+pending["expected_reply"]
                end
                channel[key]=nothing;channel["expired"]+=1
                configured_camp_trade_record!(states[actor],"expired_$key",now)
            end
        end
    end
    processing_requests && configured_camp_processing_ready!(states,foods,now)
    for caller in sort!(collect(keys(states)))
        channel=configured_camp_trade_state!(states[caller]);event=channel["outgoing"]
        event===nothing && continue
        event["created_us"]<now && in_camp(caller) || continue
        for peer in sort!(collect(keys(states)))
            (peer==caller || peer in event["heard"] || !in_camp(peer) || !world.hearing[peer]) && continue
            push!(event["heard"],peer)
            listener=configured_camp_trade_state!(states[peer]);listener["heard"]+=1
            if sleeping(peer)
                listener["sleep_ignored"]+=1;continue
            end
            # Directed speech is heard by everyone, but addressed to one person.
            if (event["addressee"]!==nothing && event["addressee"]!=peer) || busy(peer) || listener["meeting"]!==nothing || !body_alive(world.bodies[peer])
                listener["ignored"]+=1;continue
            end
            if get(event,"direction","buy")=="sell"
                if sleeping(caller) || busy(caller) || !body_alive(world.bodies[caller])
                    listener["ignored"]+=1;continue
                end
                response=configured_surplus_reply!(caller,peer,event["row"],states,maps,world,foods,now;
                    gut=guts===nothing ? nothing : guts[peer],announced=true)
                if response===nothing
                    listener["ignored"]+=1;continue
                end
                listener["replied"]+=1;channel["outgoing"]=nothing
                break
            end
            interest=configured_camp_trade_interest(event,states[peer],maps[peer],world.bodies[peer],guts===nothing ? nothing : guts[peer],foods.personal[peer],now;
                kitchen=kitchen_for(peer),relation=relations===nothing ? nothing : relations[peer],processing_requests,items,open_terms)
            if interest===nothing
                listener["ignored"]+=1;continue
            end
            listener["replied"]+=1
            supply=interest.supply
            delivered=supply["mode"]=="recipient_processing" ? supply["input"] : supply["output"]
            reply=D("peer"=>peer,"wanted"=>interest.wanted,"offered"=>supply["mode"]=="supplier_processing" ? Dict{Int,Int}() : Dict(delivered=>1),"gradient"=>interest.gradient,"supply"=>supply,"delivered"=>delivered)
            push!(event["replies"],reply)
            configured_camp_trade_record!(states[peer],"reply",now;caller,kind=event["kind"],wanted=interest.wanted,gradient=interest.gradient,supply)
        end
        get(event,"direction","buy")=="sell" && continue
        filter!(reply->begin
            peer=reply["peer"]
            in_camp(peer) && !sleeping(peer) && !busy(peer) && configured_camp_trade_state!(states[peer])["meeting"]===nothing && body_alive(world.bodies[peer])
        end,event["replies"])
        if !isempty(event["replies"]) && !sleeping(caller) && !busy(caller) && body_alive(world.bodies[caller])
            # First willing reply is a declared temporary partner-selection rule.
            reply=first(event["replies"]);peer=reply["peer"]
            configured_trade_opportunity_cancel!(states[peer],now)
            configured_camp_trade_state!(states[peer])["outgoing"]=nothing
            channel["address_H"]["$(event["kind"]):$peer"]=0.
            channel["meeting"]=D("peer"=>peer,"initiator"=>true,"kind"=>event["kind"],"announced"=>copy(reply["offered"]),"expires_us"=>event["expires_us"],"evaluated"=>false)
            configured_camp_trade_state!(states[peer])["meeting"]=D("peer"=>caller,"initiator"=>false,"kind"=>reply["wanted"],"announced"=>copy(event["offered"]),"expires_us"=>event["expires_us"],"evaluated"=>false)
            if processing_requests && reply["supply"]["mode"]!="direct"
                channel["meeting"]["goal_kind"]=event["kind"]
                channel["meeting"]["kind"]=reply["delivered"]
                channel["meeting"]["supply"]=copy(reply["supply"])
                if reply["supply"]["mode"]=="supplier_processing"
                    supplier_meeting=configured_camp_trade_state!(states[peer])["meeting"]
                    supplier_meeting["preparation"]=copy(reply["supply"])
                    deadline=max(event["expires_us"],now+reply["supply"]["ticks"]*1_000_000+CAMP_TRADE_CALL_RULES.lifetime_us)
                    channel["meeting"]["expires_us"]=deadline;supplier_meeting["expires_us"]=deadline
                end
            end
            channel["outgoing"]=nothing
            configured_camp_trade_record!(states[caller],"meeting",now;peer)
        end
    end
end
function configured_camp_trade_view(state,view,now)
    view===nothing && return nothing
    meeting=configured_camp_trade_state!(state)["meeting"]
    meeting===nothing && return view
    now<meeting["expires_us"] || return view
    out=copy(view)
    out["trade_partners"]=filter(==(meeting["peer"]),view["trade_partners"])
    out["announced_food_offers"]=D(meeting["peer"]=>copy(meeting["announced"]))
    out
end

# Temporary known communal meeting point, using the ordinary movement executor.
function configured_camp_trade_approach(state,home,position,yaw,rows;sight=nothing)
    meeting=configured_camp_trade_state!(state)["meeting"]
    meeting===nothing && return nothing
    dx,dz=home[1]-position[1],home[2]-position[2];distance=hypot(dx,dz)
    sn,cs=sincosd(yaw);forward=dx*sn+dz*cs;right=dx*cs-dz*sn
    # 既存camp_trade_callsの暫定集合経路。初期既知の中心への接近を残し、
    # 中心付近では実観測の相手へ接近する。未観測相手の真の座標は参照しない。
    # 将来は共通の人物目標MBへ置換。距離/接触の世界条件は変更しない。
    peer_seen=sight===nothing ? nothing : findfirst(p->p["ref"]==meeting["peer"],sight["peers"])
    method="camp_trade_meeting"
    if distance<=1.25
        peer_seen===nothing && return nothing
        peer=sight["peers"][peer_seen]
        peer["contact"] && return nothing
        distance=peer["distance"];forward=distance*cosd(peer["angle"]);right=distance*sind(peer["angle"])
        method="camp_trade_peer_approach"
    end
    viable=filter(r->r["cost"]!==nothing && r["clear"],rows)
    isempty(viable) && return D("action"=>"scan","direction"=>0,"method"=>"camp_trade_wait","configured_observation"=>true)
    row=viable[argmin([hypot(forward-cosd(ANGLES[parse(Int,r["ref"])+1]),right-sind(ANGLES[parse(Int,r["ref"])+1])) for r in viable])]
    D("action"=>"walk","direction"=>parse(Int,row["ref"]),"method"=>method,
        "configured_rule"=>"camp_trade_calls","configured_observation"=>true,
        "camp_trade_target"=>D("forward"=>forward,"right"=>right,"distance"=>distance))
end
function configured_camp_trade_plan!(state,view,body,gut,stock,now;processing_items=nothing,kwargs...)
    channel=configured_camp_trade_state!(state);meeting=channel["meeting"]
    incoming=view!==nothing && !isempty(get(view,"incoming",Any[]))
    if meeting===nothing || incoming
        return item_social_plan!(state,view,body,gut,stock,now;kwargs...)
    end
    meeting["initiator"] && !meeting["evaluated"] && view!==nothing && meeting["peer"] in view["trade_partners"] || return nothing
    isempty(meeting["announced"]) && return nothing # A promised product is not owned stock.
    supply=get(meeting,"supply",nothing)
    if supply!==nothing && supply["mode"]=="recipient_processing"
        trade_request_processing(get(kwargs,:map,nothing),body,gut,get(kwargs,:kitchen,nothing),meeting["kind"],meeting["goal_kind"];items=processing_items)===nothing && return nothing
    end
    mind=item_social_state!(state);previous= mind["next_us"]
    plan=item_social_plan!(state,view,body,gut,stock,now;requested_food=meeting["kind"],kwargs...)
    if mind["next_us"]!=previous
        meeting["evaluated"]=true;channel["negotiated"]+=1
        configured_camp_trade_record!(state,"proposal_evaluated",now;peer=meeting["peer"],selected=plan===nothing ? nothing : get(plan,"action",nothing))
    end
    plan
end
function configured_camp_trade_result!(states,actor,receipt,now)
    channel=configured_camp_trade_state!(states[actor]);meeting=channel["meeting"]
    meeting===nothing && return
    receipt["status"] in ("offered","countered") && return
    peer=meeting["peer"]
    for participant in (actor,peer)
        configured_trade_opportunity_finish!(states[participant],receipt["status"]=="exchanged",now;reason=receipt["status"])
    end
    configured_camp_trade_record!(states[actor],"outcome",now;peer,status=receipt["status"])
    channel["meeting"]=nothing
    other=configured_camp_trade_state!(states[peer])
    other["meeting"]!==nothing && other["meeting"]["peer"]==actor && (other["meeting"]=nothing)
end
