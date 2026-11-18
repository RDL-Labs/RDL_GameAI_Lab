# Local opt-in bridge, never included by normal LW. 暫定固定 presentation:
# a successful proposal displays its terms; response signals follow actual result.
# Replace authored expressions with learned production later. No private role,
# valuation, stock totals or result status is delivered to the learner.
const TRADE_CHANNEL_SIGNALS=Dict("offered"=>("モ","present",:initiative),
    "exchanged"=>("ユ","release",:response),"declined"=>("ケ","withdraw",:response))
mutable struct TradeChannelObserver
    words::ObservedVocabulary
    roles::RoleExperience
    pending::Dict{String,Any}
    processed::Set{String}
end
TradeChannelObserver()=TradeChannelObserver(ObservedVocabulary(),RoleExperience(),Dict{String,Any}(),Set{String}())

# 暫定固定 public handover display: successful food transfers show their batches
# between visible participants. No warehouse totals, utility or unseen outcome.
# Replace this instantaneous display with animated handovers when available.
function trade_visible_transfers(w,observer,yaw,offer,appearances;attending=true)
    (attending && offer!==nothing) || return Any[]
    sight=LW.social_sight(w,observer,yaw,0;illumination=1.)
    visible=Set(p["ref"] for p in sight["peers"]);push!(visible,observer)
    a,b=offer["proposer"],offer["target"]
    (a in visible && b in visible) || return Any[]
    transfers=Any[]
    for (origin,destination,amounts) in ((a,b,offer["give_food"]),(b,a,offer["want_food"]))
        for k in eachindex(amounts)
            amounts[k]>0 || continue
            push!(transfers,(from_visible_ref=origin,to_visible_ref=destination,
                appearance=get(appearances,k,"unresolved-food-form"),quantity=amounts[k]))
        end
    end
    transfers
end

# Own executed outcome resolves an already observed peer presentation. Do not
# teach the actor its own utterance, or invent a missed peer expression.
function trade_channel_own_result!(memory,result)
    memory===nothing && return false
    status=result["status"]
    status in ("exchanged","declined") || return false
    prior=pop!(memory.pending,result["offer_id"],nothing)
    prior===nothing && return false
    role_learn!(memory.roles,prior[1],prior[2],
        status=="exchanged" ? "object-transferred" : "object-withdrawn")
end

function trade_channel_execute!(observers,s,foods,w,stores,home,actor,op,action,now;
        speech=true,gesture=true,appearances=Dict{Int,String}(),actor_memory=nothing,spoken_words=nothing,kwargs...)
    # Closing a successful offer removes it; retain local display material first.
    prior_offer=action=="item_accept" ? deepcopy(get(s["offers"],get(kwargs,:offer_id,nothing),nothing)) : nothing
    result=LW.item_execute!(s,foods,w,stores,home,actor,op,action,now;kwargs...)
    trade_channel_own_result!(actor_memory,result)
    status=result["status"]
    haskey(TRADE_CHANNEL_SIGNALS,status) || return result
    word,motion,role=TRADE_CHANNEL_SIGNALS[status]
    spoken_words===nothing || (word=spoken_words[status])
    offer_id=result["offer_id"]
    # Only foods explicitly displayed by the proposer are exposed, not warehouse.
    shown=String[]
    if status=="offered"
        offer=s["offers"][offer_id]
        for k in eachindex(offer["give_food"])
            offer["give_food"][k]>0 && haskey(appearances,k) && push!(shown,appearances[k])
        end
    end
    event=(id=op,actor=actor,role=role,text=speech ? word : "",motion=gesture ? motion : nothing,appearances=shown)
    for (observer,settings) in observers
        memory=settings.memory
        op in memory.processed && continue
        push!(memory.processed,op)
        observation=role_public_observation(w,observer,settings.yaw,event;attending=settings.attending)
        if status=="exchanged"
            transfers=trade_visible_transfers(w,observer,settings.yaw,prior_offer,appearances;attending=settings.attending)
            if !isempty(transfers)
                observation===nothing && (observation=(id=op,text="",motion=nothing,appearances=String[]))
                observation=merge(observation,(transfers=transfers,))
            end
        end
        learn_observed_words!(memory.words,observation)
        scene=role_visible_scene(w,observer,settings.yaw,actor,
            status=="offered" ? "object-presented" : status=="exchanged" ? "object-transferred" : "object-withdrawn";
            attending=settings.attending)
        if status=="offered"
            scene===nothing || (memory.pending[offer_id]=(observation,scene))
        else
            prior=pop!(memory.pending,offer_id,nothing)
            if prior!==nothing
                role_learn!(memory.roles,prior[1],prior[2],scene)
                role_learn!(memory.roles,observation,prior[2],scene)
            end
        end
    end
    result
end
