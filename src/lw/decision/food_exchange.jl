# Initial valuation adapter; selection and experience use the common BasicLoop.
# No access to another actor's warehouse, body, preferences or hidden intentions.
const FOOD_TRADE_INTERVAL_US=64_000_000
const FOOD_TRADE_TOLERANCE=.05
function food_trade_state(seed;relational=false)
    D("world"=>food_exchange_state(),"minds"=>D(a=>D(
        "offer"=>BasicLoop(a*":food-exchange-offer";parent=a*":food-security",probabilistic=true,seed),
        "response"=>BasicLoop(a*":food-exchange-response";parent=a*":food-security",probabilistic=true,seed),
        "pending"=>nothing,"next_view_us"=>0,"next_offer_us"=>0,"relational"=>relational) for a in IDS))
end
"Known food values belong to the observer, including current taste and need."
function food_aid_values(body,gut,kinds)
    weights=food_trade_weights(body,gut)
    [weights[k]*log1p(1/(1+count(==(k),kinds))) for k in RDLBody.FOOD_KIND_IDS]
end
function food_social_context(body;give_kind=0,want_kind=0,give_count=0,want_count=0)
    context=D("need"=>clamp((80-body.reserve)/80,0.,1.))
    give_kind>0 && merge!(context,D("give_kind"=>give_kind,"give_count"=>give_count))
    want_kind>0 && merge!(context,D("want_kind"=>want_kind,"want_count"=>want_count))
    context
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
food_trade_actual(weights,result)=result["status"]=="exchanged" ?
    sum(weights[k]*(log1p(result["own_after"][k])-log1p(result["own_before"][k])) for k in RDLBody.FOOD_KIND_IDS) : 0.
function food_trade_resolve!(loop,source,expected,weights,result;relational=false)
    exchanged=result["status"]=="exchanged"
    # Freeze valuation at selection; evaluate only the committed swap, excluding
    # intervening meals/withdrawals and never reading the partner's warehouse.
    actual=food_trade_actual(weights,result)
    if relational
        return resolve_prediction!(loop,source,expected,actual;fulfilled=exchanged,tolerance=FOOD_TRADE_TOLERANCE)
    end
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
function food_trade_views!(t,r,w,home,now;relations=nothing)
    food_exchange_expire!(t["world"],now)
    views=D()
    for a in IDS
        relations!==nothing && check(relations[a]["actor"]==a,"trade_relation_owner")
        mind=t["minds"][a]
        incoming=any(o->o["target"]==a,values(t["world"]["offers"]))
        if mind["pending"]!==nothing || incoming || now>=mind["next_view_us"]
            view=food_exchange_view(t["world"],r,w,home,a,now)
            views[a]=view;mind["next_view_us"]=now+FOOD_TRADE_INTERVAL_US
            pending=mind["pending"]
            if pending!==nothing
                notice=findfirst(n->n["offer_id"]==pending["offer_id"],view["notices"])
                if notice!==nothing
                    result=view["notices"][notice]
                    gradient_result!(relations===nothing ? nothing : relations[a],pending["source"],result["status"];actual=food_trade_actual(pending["weights"],result),now=result["us"])
                    food_trade_resolve!(mind["offer"],pending["source"],get(pending,"expected",pending["gain"]),pending["weights"],result;relational=get(mind,"relational",false))
                    relations!==nothing && social_relation_event!(relations[a],pending["partner"],"trade_offer",
                        pending["offer_id"],result["us"];outcome=result["status"],value=food_trade_actual(pending["weights"],result),context=get(pending,"context",nothing))
                    mind["pending"]=nothing
                end
            end
        end
    end
    views
end
function food_trade_plan!(t,a,view,body,gut,now;relation=nothing,require_need=true)
    relation!==nothing && check(relation["actor"]==a,"trade_relation_owner")
    view===nothing && return nothing
    mind=t["minds"][a];stock=view["own_stock"]
    security=food_security(relation);need=trade_food_need(body,gut,stock;security)
    if require_need && isempty(view["incoming"]) && need<=1e-9
        mind["need_skipped"]=get(mind,"need_skipped",0)+1
        return nothing
    end
    weights=food_trade_weights(body,gut)
    relief(g,n,h,m)=begin
        give=zeros(Int,4);want=zeros(Int,4);give[g]=n;want[h]=m
        trade_food_relief(body,gut,stock,give,want;security)
    end
    source="trade:$now:$a"
    if !isempty(view["incoming"])
        offer=first(view["incoming"]);other=offer["proposer"]
        situation=food_social_context(body;give_kind=offer["want_kind"],want_kind=offer["give_kind"],give_count=offer["want_count"],want_count=offer["give_count"])
        situation=social_observed_context(relation,other,situation)
        relation_trace=relation===nothing ? nothing : social_relation_bias(relation,other,"trade_response";situation,H=mind["response"].H)
        gain=food_trade_gain(stock,weights,offer["want_kind"],offer["want_count"],offer["give_kind"],offer["give_count"])
        candidates=Any[D("method"=>"decline:$other","action"=>"trade_decline","priority"=>0.,"question"=>"stock_value_improved",
            "offer_id"=>offer["id"],"trade_gain"=>0.)]
        if gain!==nothing && (!require_need || (need>1e-9 && relief(offer["want_kind"],offer["want_count"],offer["give_kind"],offer["give_count"])>1e-9 && gain>FOOD_TRADE_TOLERANCE))
            method="accept:$other:$(offer["give_kind"]):$(offer["give_count"]):$(offer["want_kind"]):$(offer["want_count"])"
            push!(candidates,D("method"=>method,"action"=>"trade_accept","priority"=>4gain-.2+(relation_trace===nothing ? 0. : relation_trace["weight"]),
                "question"=>"stock_value_improved","offer_id"=>offer["id"],"trade_gain"=>gain))
        end
        for c in candidates;c["gradient_relation"]=relation_trace;c["context"]=situation;end
        plan=choose_method!(mind["response"],candidates,source)
        gradient_capture!(relation,mind["response"],candidates,plan,source,now;channel="food_trade_response")
        plan["trade_role"]="response";plan["trade_source"]=source
        plan["trade_weights"]=weights
        plan["trade_context"]=situation
        plan["trade_partner"]=other;plan["food_exchange"]=true
        if relation!==nothing
            social_relation_use!(relation,other,"trade_response",source,now,
                merge(relation_trace,D("applies_to"=>"trade_accept"));action=plan["action"])
        end
        mind["next_offer_us"]=now+FOOD_TRADE_INTERVAL_US
        return plan
    end
    mind["pending"]===nothing && view["outgoing"]===nothing && now>=mind["next_offer_us"] || return nothing
    mind["next_offer_us"]=now+FOOD_TRADE_INTERVAL_US
    isempty(view["partners"]) && return nothing
    candidates=Any[]
    relation_traces=D()
    for other in view["partners"], g in RDLBody.FOOD_KIND_IDS, n in 1:min(4,stock[g]), h in RDLBody.FOOD_KIND_IDS, m in 1:4
        g==h && continue
        require_need && relief(g,n,h,m)<=1e-9 && continue
        gain=food_trade_gain(stock,weights,g,n,h,m)
        require_need && gain<=FOOD_TRADE_TOLERANCE && continue
        situation=food_social_context(body;give_kind=g,want_kind=h,give_count=n,want_count=m)
        situation=social_observed_context(relation,other,situation)
        trace_key="$other:$g:$n:$h:$m"
        relation!==nothing && (relation_traces[trace_key]=social_relation_bias(relation,other,"trade_offer";situation,H=mind["offer"].H))
        expected=get(mind,"relational",false) && relation!==nothing ? gain*relation_traces[trace_key]["profile"]["trade_probability"] : gain
        push!(candidates,D("method"=>"offer:$other:$g:$n:$h:$m","action"=>"trade_offer","priority"=>4gain-1. + (relation===nothing ? 0. : relation_traces[trace_key]["weight"]),
            "question"=>"stock_value_improved","target"=>other,"give_kind"=>g,"give_count"=>n,
            "want_kind"=>h,"want_count"=>m,"trade_gain"=>gain,"trade_expected_gain"=>expected,"trade_context"=>situation,"trade_trace_key"=>trace_key))
    end
    isempty(candidates) && return nothing
    # More quantity combinations must not by themselves overwhelm continuing activity.
    prior=-log(length(candidates))
    for c in candidates;c["observation_log_prior"]=prior;end
    push!(candidates,D("method"=>"continue_activity","action"=>"trade_skip","priority"=>0.,"question"=>"stock_value_improved"))
    for c in candidates;c["gradient_relation"]=get(relation_traces,get(c,"trade_trace_key",""),nothing);end
    plan=choose_method!(mind["offer"],candidates,source)
    gradient_capture!(relation,mind["offer"],candidates,plan,source,now;channel="food_trade_offer")
    if plan["action"]=="trade_skip"
        gradient_result!(relation,source,"continued";now)
        resolve_method!(mind["offer"],source,nothing,nothing;creditable=false,goal_H_increment=0.)
        return nothing
    end
    plan["trade_role"]="offer";plan["trade_source"]=source
    plan["trade_weights"]=weights
    plan["trade_partner"]=plan["target"];plan["food_exchange"]=true
    relation!==nothing && social_relation_use!(relation,plan["target"],"trade_offer",source,now,relation_traces[plan["trade_trace_key"]];action=plan["action"])
    plan
end
function food_trade_executed!(t,a,plan,result;relation=nothing)
    relation!==nothing && check(relation["actor"]==a,"trade_relation_owner")
    mind=t["minds"][a];role=plan["trade_role"];source=plan["trade_source"]
    gradient_result!(relation,source,result["status"];actual=result["status"]=="offered" ? nothing : food_trade_actual(plan["trade_weights"],result),now=result["us"])
    if role=="offer" && result["status"]=="offered"
        mind["pending"]=D("offer_id"=>result["offer_id"],"source"=>source,"gain"=>plan["trade_gain"],"expected"=>get(plan,"trade_expected_gain",plan["trade_gain"]),"weights"=>copy(plan["trade_weights"]),"partner"=>plan["target"],"context"=>deepcopy(get(plan,"trade_context",nothing)))
    elseif plan["action"]=="trade_decline"
        resolve_method!(mind["response"],source,nothing,nothing;creditable=false,goal_H_increment=0.)
    else
        food_trade_resolve!(mind[role],source,get(plan,"trade_expected_gain",plan["trade_gain"]),plan["trade_weights"],result;relational=get(mind,"relational",false))
    end
    if relation!==nothing && result["status"]!="offered"
        social_relation_event!(relation,plan["trade_partner"],role=="offer" ? "trade_offer" : "trade_response",source,
            result["us"];outcome=result["status"],value=food_trade_actual(plan["trade_weights"],result),context=get(plan,"trade_context",nothing))
    end
end
food_trade_snapshot(t)=D("world"=>food_exchange_snapshot(t["world"]),
    "learning"=>D(a=>D("offer"=>loop_snapshot(m["offer"]),"response"=>loop_snapshot(m["response"]),
        "pending"=>deepcopy(m["pending"]),"need_skipped"=>get(m,"need_skipped",0)) for (a,m) in t["minds"]))
