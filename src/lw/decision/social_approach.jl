# Approach is one food-purpose method competing with ordinary navigation.
# It predicts access to an interaction, never received food or guaranteed help.
function social_approach_candidates(view,move,relation,loop,now;purpose="aid",food_value=1.,food_values=nothing,context=nothing)
    view===nothing && return Any[]
    check(purpose in ("aid","trade"),"social_approach_purpose")
    check(food_value isa Real && !(food_value isa Bool) && isfinite(food_value) && food_value>=0,
        "social_approach_value")
    check(food_values===nothing || (food_values isa AbstractVector && length(food_values)==4 &&
        all(v->v isa Real && !(v isa Bool) && isfinite(v) && v>=0,food_values)),"social_approach_food_values")
    check(view["capture_us"]==now && view["source"]=="ob:$now:$(view["actor"])","social_approach_observation")
    relation===nothing && return Any[]
    check(relation["actor"]==view["actor"],"social_approach_owner")
    (food_values===nothing ? food_value>0 : any(>(0),food_values)) || return Any[] # No intrinsic social reward.
    out=Any[];seen=Set{String}();use=purpose=="aid" ? "request" : "trade_offer"
    for peer in view["peers"]
        other=peer["ref"]
        check(other!=view["actor"] && !(other in seen),"social_approach_peer")
        push!(seen,other)
        peer["contact"] && continue # Existing request/offer code owns contact actions.
        angle=peer["angle"]
        rows=[r for r in move["energy"]["rows"] if r["cost"]!==nothing &&
            abs(ANGLES[parse(Int,r["ref"])+1]-angle)<=22.5]
        isempty(rows) && continue
        sort!(rows;by=r->(abs(ANGLES[parse(Int,r["ref"])+1]-angle),r["cost"],r["ref"]))
        row=first(rows)
        trace=social_relation_bias(relation,other,use;situation=context,H=loop.H)
        profile=trace["profile"]
        probability=profile[purpose=="aid" ? "aid_probability" : "trade_probability"]
        value=Float64(food_value)
        if purpose=="aid" && food_values!==nothing
            prediction=get(get(profile,"predictions",D()),"aid",D())
            kinds=get(prediction,"kind_probabilities",Dict{Int,Float64}())
            # Which food might arrive is learned from this owner's past
            # receipts; its value is recomputed under this owner's taste/need.
            value=isempty(kinds) ? sum(food_values)/length(food_values) :
                sum(p*food_values[k] for (k,p) in kinds)
        end
        expected=value*probability
        # The common exploration walk has base priority 1.5. Additional value
        # is an expected owner-side gain, discounted by observed travel expense.
        # The same aid probability is not added again as a social-bias bonus.
        reserve_cost=max(0.,-get(get(row,"expected_delta",D()),"reserve",0.))
        priority=1.5+2log1p(expected)-.2log1p(peer["distance"])-reserve_cost
        push!(out,D("method"=>"social_approach:$purpose:$other","action"=>"walk",
            "direction"=>parse(Int,row["ref"]),"steering_angle"=>angle,"priority"=>priority,
            "question"=>"social_contact","social_actor"=>view["actor"],"social_peer"=>other,
            "social_purpose"=>purpose,"social_expected_gain"=>expected,
            "social_conditional_value"=>value,
            "social_probability"=>probability,"social_source"=>view["source"],
            "social_capture_us"=>Int(now),"social_distance"=>peer["distance"],
            "social_relation"=>trace))
    end
    sort!(out;by=c->(-c["priority"],c["method"]))
    # The same small-H-tolerant width as observed MB correspondence: familiar
    # strong opportunities first, weaker current opportunities as pressure grows.
    resize!(out,min(length(out),8,mb_retrieval_budget(loop.H)))
    out
end

# Current observation can confirm contact only. Losing sight, a coarse range
# tie, or elapsed time is not itself a failed interaction or acquired food.
function social_approach_evidence(choice,view)
    view===nothing && return nothing
    check(choice["social_actor"]==view["actor"],"social_approach_evidence_owner")
    view["capture_us"]>choice["social_capture_us"] || return nothing
    peer=findfirst(p->p["ref"]==choice["social_peer"],view["peers"])
    peer===nothing || !view["peers"][peer]["contact"] ? nothing : true
end
