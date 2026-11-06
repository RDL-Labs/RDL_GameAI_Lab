include("../parameters.jl")
# Owner-local forecast. Food-search estimates are the same learned parent MB
# estimates used by navigation; successful promises are never counted as stock.
food_security_state()=D("H"=>0.,"required"=>1.,"shortfall"=>0.,"next_us"=>0,
    "last_us"=>nothing,"last_metabolism"=>0.,"rate"=>nothing,"samples"=>0,
    "estimate"=>nothing,"records"=>Any[],"attention"=>nothing,"requests"=>0)
food_security(s)=s===nothing ? nothing : get(s,"food_security",nothing)
"Expressed anxiety is distinct from the raw shortage retained for planning."
food_anxiety(s)=s===nothing ? 0. : FOOD_SECURITY_RULES.anxiety_gain*max(0.,get(s,"H",0.)/max(1.,get(s,"required",1.))-FOOD_SECURITY_RULES.anxiety_band)^FOOD_SECURITY_RULES.anxiety_power

# Shared provisional valuation coefficients, not a forced action or a personality
# difference. Only owner forecasts are used; no unseen world food is consulted.
function food_self_reliance(state,map,body)
    estimate=state["estimate"]
    estimate===nothing && return D("confidence"=>0.,"seconds"=>nothing,"runway"=>nothing)
    choice=map===nothing ? nothing : get(get(map,"acquisition",D()),"choice",nothing)
    seconds=choice===nothing ? estimate["search_seconds"] : choice["seconds"]
    uncertainty=choice===nothing ? 1. : max(0.,choice["uncertainty"])
    failure=0.
    if choice!==nothing
        acquisition=get(map,"acquisition",D())
        technique=get(choice,"technique","explore")
        failure=max(get(get(get(acquisition,"methods",D()),technique,D()),"H",0.),
            get(get(get(acquisition,"sites",D()),acquisition_key(technique,get(choice,"ref",nothing)),D()),"H",0.))
    end
    rate=max(eps(Float64),estimate["metabolic_rate"])
    energy=max(0.,body.reserve-FOOD_SECURITY_RULES.reserve_floor)+get(state,"supplied",0.)*RDLBody.MEAL_ENERGY
    runway=energy/rate
    duration=max(1.,seconds*(1+uncertainty))
    confidence=clamp(runway/duration,0.,1.)/(1+uncertainty+failure)
    D("confidence"=>confidence,"seconds"=>duration,"base_seconds"=>seconds,"runway"=>runway,
        "uncertainty"=>uncertainty,"failure"=>failure)
end
function food_request_ready(state,now)
    state!==nothing && (food_anxiety(state)>0 || get(state,"body_shortfall",0.)>0) && now>=get(state,"next_request_us",0)
end
function food_request_considered!(state,now)
    food_request_ready(state,now) || return false
    state["next_request_us"]=now+FOOD_SECURITY_RULES.request_interval_us
    state["requests"]+=1
    true
end

function food_security_update!(state,map,body,gut,stock,kinds,metabolic_loss,now,day_us;target=nothing)
    day_seconds=day_us/1e6
    if state["estimate"]===nothing || now>=state["next_us"]
        previous=state["last_us"]
        if previous!==nothing && now>previous && body.reserve>0
            rate=max(0.,metabolic_loss-state["last_metabolism"])/((now-previous)/1e6)
            state["rate"]=state["rate"]===nothing ? rate : .9state["rate"]+.1rate
            state["samples"]+=1
        end
        state["last_us"]=now;state["last_metabolism"]=metabolic_loss
        estimate=map===nothing ? D("upper_actions"=>256.,"energy"=>2.56,"source"=>"bootstrap") :
            mb_parent_estimate!(map,D(),"food",target;use_arrival=false)
        choice=map===nothing ? nothing : get(get(map,"acquisition",D()),"choice",nothing)
        if choice!==nothing
            estimate=copy(estimate)
            estimate["upper_actions"]=max(estimate["upper_actions"],choice["seconds"]*(1+choice["uncertainty"]))
        end
        # The uncertainty allowance is an explicit prior, not a promised supply.
        # Learned MB duration and movement energy supplement measured metabolism.
        horizon=choice===nothing ? max(day_seconds,Float64(estimate["upper_actions"]))+2day_seconds : 3day_seconds+Float64(estimate["upper_actions"])
        rate=state["rate"]===nothing ? RDLBody.MEAL_ENERGY/day_seconds : state["rate"]
        state["estimate"]=D("horizon_seconds"=>horizon,"energy"=>rate*horizon+estimate["energy"],
            "search_energy"=>estimate["energy"],
            "source"=>estimate["source"],"search_seconds"=>estimate["upper_actions"],
            "metabolic_rate"=>rate,"samples"=>state["samples"])
        state["next_us"]=now+FOOD_SECURITY_RULES.forecast_interval_us
    end
    # Preserve a reserve floor rather than treating the whole body as expendable.
    required=max(1.,(state["estimate"]["energy"]-max(0.,body.reserve-FOOD_SECURITY_RULES.reserve_floor))/RDLBody.MEAL_ENERGY)
    units(k)=RDLBody.food_edible(k) ? 1. : RDLBody.FOOD_PROCESS_OUTPUT[k]!=0 ? .65 : map===nothing ? 0. : food_condition_usable(map,k)
    supplied=gut===nothing ? 0. : gut.gut
    days_ahead=ceil(Int,state["estimate"]["horizon_seconds"]/day_seconds)
    # Keep the portion plausibly eaten today at full value; only the surplus
    # relies on learned overnight retention, not a hard-coded fish deadline.
    expiry=food_expiry_forecast(map,body,gut;now,day_us)
    state["expiry"]=expiry
    today_need=expiry["capacity"]
    for k in sort(collect(eachindex(stock));by=k->food_storage_survival(map,k,days_ahead))
        n=stock[k]+count(==(k),kinds)
        immediate=min(n,today_need)
        (RDLBody.food_edible(k) || RDLBody.FOOD_PROCESS_OUTPUT[k]!=0) && (today_need-=immediate)
        supplied+=units(k)*(immediate+(n-immediate)*food_storage_survival(map,k,days_ahead))
    end
    before=state["H"];shortfall=max(0.,required-supplied)
    state["required"]=required;state["shortfall"]=shortfall;state["supplied"]=supplied
    state["H"]=max(0.,shortfall-FOOD_SECURITY_RULES.raw_residual_band) # residual band, never a per-tick failure counter
    state["body_shortfall"]=max(0.,(FOOD_SECURITY_RULES.request_reserve_floor-body.reserve)/FOOD_SECURITY_RULES.request_reserve_floor)
    state["self_reliance"]=food_self_reliance(state,map,body)
    if isempty(state["records"]) || now-last(state["records"])["us"]>=64_000_000
        push!(state["records"],D("us"=>now,"required"=>required,"supplied"=>supplied,
            "H"=>state["H"],"increment"=>max(0.,state["H"]-before),"relief"=>max(0.,before-state["H"]),
            "anxiety"=>food_anxiety(state),"body_shortfall"=>state["body_shortfall"],
            "self_reliance"=>copy(state["self_reliance"]),"estimate"=>copy(state["estimate"])))
        length(state["records"])>64 && popfirst!(state["records"])
    end
    state
end

# One owner-local forecast shared by provisioning and social valuation.
function food_security_for!(map,relation)
    if map===nothing
        relation===nothing && return nothing
        return get!(food_security_state,relation,"food_security")
    end
    state=get!(()->relation===nothing ? food_security_state() :
        get!(food_security_state,relation,"food_security"),map,"food_security")
    relation!==nothing && (relation["food_security"]=state)
    state
end

function food_provision_candidates(security)
    required=max(1.,security["required"]);supplied=get(security,"supplied",0.)
    pressure=security["H"] # Small shortages still motivate preparation, before felt anxiety.
    margin=max(0.,supplied-required)/required
    estimate=security["estimate"]
    cost=estimate===nothing ? 0. : max(0.,get(estimate,"search_energy",0.))/RDLBody.MEAL_ENERGY
    # Forecast relief versus the value of retaining a sufficient stock without
    # spending effort. Log scaling avoids a linear domination by large stores.
    relief=log1p(pressure);slack=log1p(margin)
    acquire=relational_transition(-relief,0.;cost=log1p(cost))
    remain=relational_transition(0.,slack-relief)
    [D("method"=>"provision_outing","priority"=>acquire.expected,"field"=>acquire),
     D("method"=>"provision_stay","priority"=>remain.expected,"field"=>remain)]
end

function food_provision_stay!(map,security,at_home,now,day_us)
    at_home && security!==nothing || return false
    daily=map["daily_plan"];active=daily["active"]
    # An underway outing keeps its own goal and deadline. This is a start decision.
    active!==nothing && now<active["deadline_us"] && return false
    state=get!(() -> D("day"=>-1,"choice"=>nothing,"H"=>0.,"next_us"=>0,
        "records"=>Any[],"stay_ticks"=>0,"stay_choices"=>0,"outing_choices"=>0),map,"provision_choice")
    day=fld(now,day_us);pressure=food_anxiety(security)
    reconsider=state["day"]!=day || state["choice"]===nothing ||
        (state["choice"]=="provision_stay" && pressure>state["H"]+.1 && now>=state["next_us"])
    if reconsider
        loop=BasicLoop("provision-start";probabilistic=true);loop.rng=daily["rng"]
        # Anxiety is already the valuation residual, not a second temperature multiplier.
        candidates=food_provision_candidates(security);probabilities=method_distribution(loop,candidates)
        index=rand(loop.rng)<probabilities[1] ? 1 : 2
        choice=candidates[index]["method"]
        state["day"]=day;state["choice"]=choice;state["H"]=pressure;state["next_us"]=now+FOOD_SECURITY_RULES.forecast_interval_us
        state[choice=="provision_stay" ? "stay_choices" : "outing_choices"]+=1
        mb_daily_log!(state["records"],D("us"=>now,"day"=>day,"choice"=>choice,"H"=>pressure,
            "required"=>security["required"],"supplied"=>get(security,"supplied",0.),
            "candidates"=>candidates,"probabilities"=>probabilities))
        if choice=="provision_stay" && active!==nothing && !active["closed"]
            mb_daily_close!(daily,now,false,"provision_deferred")
        end
    end
    state["choice"]=="provision_stay"
end

# A shared current observation, not a lookup of the partner's hidden condition.
function social_observed_context(relation,other,context=D())
    out=context===nothing ? D() : copy(context)
    view=relation===nothing ? nothing : get(relation,"social_view",nothing)
    view===nothing && return out
    i=findfirst(p->p["ref"]==other,view["peers"]);i===nothing && return out
    face=view["peers"][i]["expression"]
    face===nothing && return out
    out["distress"]=face.distress;out["fear"]=face.fear
    out
end
function social_aid_context(relation,other,context=D())
    out=social_observed_context(relation,other,context)
    resources=relation===nothing ? nothing : get(get(relation,"aid_resources",D()),other,nothing)
    resources!==nothing && merge!(out,resources)
    out
end
function aid_resource_observe!(relation,contacts,stocks,conditions)
    resources=D()
    for peer in contacts
        other=peer["ref"];known=haskey(stocks,other);counts=known ? stocks[other] : Int[]
        edible=sum((counts[k] for k in eachindex(counts) if RDLBody.food_edible(k));init=0)
        faded=sum((row["count"] for row in get(conditions,other,Any[]) if
            row["condition"]==1 && RDLBody.food_edible(row["kind"]));init=0)
        entry=D("holding_food"=>Float64(peer["holding_food"]),"stock_known"=>Float64(known),
            "stock_edible"=>log1p(edible),"stock_faded"=>log1p(min(edible,faded)))
        for k in eachindex(counts);entry["stock_kind_$k"]=log1p(counts[k]);end
        resources[other]=entry
    end
    relation["aid_resources"]=resources # current observation only; no stale hidden lookup
end
function aid_resource_prediction(context)
    known=get(context,"stock_known",0.)>0
    held=get(context,"holding_food",0.)>0
    edible=max(0.,expm1(get(context,"stock_edible",0.)))
    faded=min(edible,max(0.,expm1(get(context,"stock_faded",0.))))
    usable=edible-(1-AID_RESOURCE_RULES.faded_weight)*faded
    availability=held ? 1. : known ? AID_RESOURCE_RULES.store_access_weight*usable/(1+usable) : AID_RESOURCE_RULES.unknown_availability
    retention=1/(1+AID_RESOURCE_RULES.distress_retention*get(context,"distress",0.)/(1+usable))
    D("availability"=>availability,"retention"=>retention,"factor"=>availability*retention,
      "source"=>"observed_resources_and_expression","stock_known"=>known)
end
function social_attention(relation,now)
    relation===nothing && return nothing
    # A recent interaction makes its partner worth examining, without bypassing FOV.
    for c in reverse(relation["choices"])
        now-get(c,"us",0)<=64_000_000 && return get(c,"other",nothing)
    end
    view=get(relation,"social_view",nothing)
    view===nothing && return nothing
    best=nothing;weight=0.
    for p in view["peers"]
        f=p["expression"];f===nothing && continue
        w=max(f.distress,f.fear)/(1+p["distance"])
        w>weight && (best=p["ref"];weight=w)
    end
    best
end
