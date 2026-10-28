# Initial valuation adapter; selection and experience use the common BasicLoop.
# No access to another actor's warehouse, body, preferences or hidden intentions.
const FOOD_TRADE_INTERVAL_US=64_000_000
const FOOD_TRADE_TOLERANCE=.05
function food_trade_state(seed)
    D("world"=>food_exchange_state(),"minds"=>D(a=>D(
        "offer"=>BasicLoop(a*":food-exchange-offer";parent=a*":food-security",probabilistic=true,seed),
        "response"=>BasicLoop(a*":food-exchange-response";parent=a*":food-security",probabilistic=true,seed),
        "pending"=>nothing,"next_view_us"=>0,"next_offer_us"=>0) for a in IDS))
end
function food_trade_weights(body,gut)
    need=clamp((80-body.reserve)/80,0.,1.)
    [begin
        edible=RDLBody.food_edible(k)
        meal=edible ? k : RDLBody.FOOD_PROCESS_OUTPUT[k]
        liking=meal==0 ? 0. : gut===nothing ? FOOD_LIKING[meal] : taste(gut,meal,body.reserve)
        # A known recipe predicts an edible result but still requires work.
        (.2+.6need+liking)*(edible ? 1. : .65)
    end for k in RDLBody.FOOD_KIND_IDS]
end
function food_trade_gain(stock,weights,g,n,h,m)
    stock[g]>=n || return nothing
    weights[g]*(log1p(stock[g]-n)-log1p(stock[g]))+
        weights[h]*(log1p(stock[h]+m)-log1p(stock[h]))
end
function food_trade_resolve!(loop,source,expected,weights,result)
    exchanged=result["status"]=="exchanged"
    # Freeze valuation at selection; evaluate only the committed swap, excluding
    # intervening meals/withdrawals and never reading the partner's warehouse.
    actual=exchanged ? sum(weights[k]*(log1p(result["own_after"][k])-log1p(result["own_before"][k]))
        for k in RDLBody.FOOD_KIND_IDS) : 0.
    pressure=max(0.,expected-actual-FOOD_TRADE_TOLERANCE,-actual-FOOD_TRADE_TOLERANCE)
    useful=exchanged && actual>FOOD_TRADE_TOLERANCE
    if useful && pressure==0.
        resolve_method!(loop,source,true,true;goal_H_increment=0.,completion_reward=actual-FOOD_TRADE_TOLERANCE)
    elseif pressure>0.
        # A useful swap can still fall short of the prediction: partial method
        # success, with unmet goal pressure retained by the common loop.
        resolve_method!(loop,source,useful,false;creditable=useful,goal_H_increment=pressure)
    else
        resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
    end
end
function food_trade_views!(t,r,w,home,now)
    food_exchange_expire!(t["world"],now)
    views=D()
    for a in IDS
        mind=t["minds"][a]
        incoming=any(o->o["target"]==a,values(t["world"]["offers"]))
        if mind["pending"]!==nothing || incoming || now>=mind["next_view_us"]
            view=food_exchange_view(t["world"],r,w,home,a,now)
            views[a]=view;mind["next_view_us"]=now+FOOD_TRADE_INTERVAL_US
            pending=mind["pending"]
            if pending!==nothing
                notice=findfirst(n->n["offer_id"]==pending["offer_id"],view["notices"])
                if notice!==nothing
                    food_trade_resolve!(mind["offer"],pending["source"],pending["gain"],pending["weights"],view["notices"][notice])
                    mind["pending"]=nothing
                end
            end
        end
    end
    views
end
function food_trade_plan!(t,a,view,body,gut,now)
    view===nothing && return nothing
    mind=t["minds"][a];stock=view["own_stock"];weights=food_trade_weights(body,gut)
    source="trade:$now:$a"
    if !isempty(view["incoming"])
        offer=first(view["incoming"]);other=offer["proposer"]
        gain=food_trade_gain(stock,weights,offer["want_kind"],offer["want_count"],offer["give_kind"],offer["give_count"])
        candidates=Any[D("method"=>"decline:$other","action"=>"trade_decline","priority"=>0.,"question"=>"stock_value_improved",
            "offer_id"=>offer["id"],"trade_gain"=>0.)]
        if gain!==nothing
            method="accept:$other:$(offer["give_kind"]):$(offer["give_count"]):$(offer["want_kind"]):$(offer["want_count"])"
            push!(candidates,D("method"=>method,"action"=>"trade_accept","priority"=>4gain-.2,
                "question"=>"stock_value_improved","offer_id"=>offer["id"],"trade_gain"=>gain))
        end
        plan=choose_method!(mind["response"],candidates,source)
        plan["trade_role"]="response";plan["trade_source"]=source
        plan["trade_weights"]=weights
        plan["trade_partner"]=other;plan["food_exchange"]=true
        mind["next_offer_us"]=now+FOOD_TRADE_INTERVAL_US
        return plan
    end
    mind["pending"]===nothing && view["outgoing"]===nothing && now>=mind["next_offer_us"] || return nothing
    mind["next_offer_us"]=now+FOOD_TRADE_INTERVAL_US
    isempty(view["partners"]) && return nothing
    candidates=Any[]
    for other in view["partners"], g in RDLBody.FOOD_KIND_IDS, n in 1:min(4,stock[g]), h in RDLBody.FOOD_KIND_IDS, m in 1:4
        g==h && continue
        gain=food_trade_gain(stock,weights,g,n,h,m)
        push!(candidates,D("method"=>"offer:$other:$g:$n:$h:$m","action"=>"trade_offer","priority"=>4gain-1.,
            "question"=>"stock_value_improved","target"=>other,"give_kind"=>g,"give_count"=>n,
            "want_kind"=>h,"want_count"=>m,"trade_gain"=>gain))
    end
    isempty(candidates) && return nothing
    # More quantity combinations must not by themselves overwhelm continuing activity.
    prior=-log(length(candidates))
    for c in candidates;c["observation_log_prior"]=prior;end
    push!(candidates,D("method"=>"continue_activity","action"=>"trade_skip","priority"=>0.,"question"=>"stock_value_improved"))
    plan=choose_method!(mind["offer"],candidates,source)
    if plan["action"]=="trade_skip"
        resolve_method!(mind["offer"],source,nothing,nothing;creditable=false,goal_H_increment=0.)
        return nothing
    end
    plan["trade_role"]="offer";plan["trade_source"]=source
    plan["trade_weights"]=weights
    plan["trade_partner"]=plan["target"];plan["food_exchange"]=true
    plan
end
function food_trade_executed!(t,a,plan,result)
    mind=t["minds"][a];role=plan["trade_role"];source=plan["trade_source"]
    if role=="offer" && result["status"]=="offered"
        mind["pending"]=D("offer_id"=>result["offer_id"],"source"=>source,"gain"=>plan["trade_gain"],"weights"=>copy(plan["trade_weights"]))
    elseif plan["action"]=="trade_decline"
        resolve_method!(mind["response"],source,nothing,nothing;creditable=false,goal_H_increment=0.)
    else
        food_trade_resolve!(mind[role],source,plan["trade_gain"],plan["trade_weights"],result)
    end
end
food_trade_snapshot(t)=D("world"=>food_exchange_snapshot(t["world"]),
    "learning"=>D(a=>D("offer"=>loop_snapshot(m["offer"]),"response"=>loop_snapshot(m["response"]),
        "pending"=>deepcopy(m["pending"])) for (a,m) in t["minds"]))
