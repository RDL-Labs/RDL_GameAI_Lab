# Owner-local forecast. Food-search estimates are the same learned parent MB
# estimates used by navigation; successful promises are never counted as stock.
food_security_state()=D("H"=>0.,"required"=>1.,"shortfall"=>0.,"next_us"=>0,
    "last_us"=>nothing,"last_metabolism"=>0.,"rate"=>nothing,"samples"=>0,
    "estimate"=>nothing,"records"=>Any[],"attention"=>nothing,"requests"=>0)
food_security(s)=s===nothing ? nothing : get(s,"food_security",nothing)
food_anxiety(s)=s===nothing ? 0. : get(s,"H",0.)
function food_request_ready(state,now)
    state!==nothing && state["H"]>0 && now>=get(state,"next_request_us",0)
end
function food_request_considered!(state,now)
    food_request_ready(state,now) || return false
    state["next_request_us"]=now+64_000_000
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
            mb_parent_estimate!(map,D(),"food",target)
        # The uncertainty allowance is an explicit prior, not a promised supply.
        # Learned MB duration and movement energy supplement measured metabolism.
        horizon=max(day_seconds,Float64(estimate["upper_actions"]))+2day_seconds
        rate=state["rate"]===nothing ? RDLBody.MEAL_ENERGY/day_seconds : state["rate"]
        state["estimate"]=D("horizon_seconds"=>horizon,"energy"=>rate*horizon+estimate["energy"],
            "source"=>estimate["source"],"search_seconds"=>estimate["upper_actions"],
            "metabolic_rate"=>rate,"samples"=>state["samples"])
        state["next_us"]=now+64_000_000
    end
    # Preserve a reserve floor rather than treating the whole body as expendable.
    required=max(1.,(state["estimate"]["energy"]-max(0.,body.reserve-70.))/RDLBody.MEAL_ENERGY)
    supplied=sum((RDLBody.food_edible(k) ? 1. : .65 for k in kinds);init=0.)+
        sum(((RDLBody.food_edible(k) ? 1. : RDLBody.FOOD_PROCESS_OUTPUT[k]!=0 ? .65 : 0.)*stock[k] for k in eachindex(stock));init=0.)+
        (gut===nothing ? 0. : gut.gut)
    before=state["H"];shortfall=max(0.,required-supplied)
    state["required"]=required;state["shortfall"]=shortfall
    state["H"]=max(0.,shortfall-.1) # residual band, never a per-tick failure counter
    if isempty(state["records"]) || now-last(state["records"])["us"]>=64_000_000
        push!(state["records"],D("us"=>now,"required"=>required,"supplied"=>supplied,
            "H"=>state["H"],"increment"=>max(0.,state["H"]-before),"relief"=>max(0.,before-state["H"]),
            "estimate"=>copy(state["estimate"])))
        length(state["records"])>64 && popfirst!(state["records"])
    end
    state
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
