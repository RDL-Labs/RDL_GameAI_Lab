# Local prototype: sender roles organize production, never label receiver input.
const COMMUNICATION_ROLES = (:attention, :initiative, :response)
mutable struct RoleExperience
    associations::Dict{Tuple{String,String},Dict{String,Int}}
    receipts::Dict{String,Any}
end
RoleExperience()=RoleExperience(Dict{Tuple{String,String},Dict{String,Int}}(),Dict{String,Any}())

function role_public_observation(w,observer,yaw,event;attending=true)
    event.role in COMMUNICATION_ROLES || error("unknown sender role")
    # Only the existing sensor projection is returned, not role/intention.
    observe_trade_event(w,observer,yaw,event;attending)
end

function role_learn!(memory,observation,before,after)
    (observation===nothing || before===nothing || after===nothing) && return false
    # before/after must themselves be sensor observations, not private plans.
    record=(observation,before,after)
    if haskey(memory.receipts,observation.id)
        memory.receipts[observation.id]==record || error("conflicting observed episode")
        return false
    end
    memory.receipts[observation.id]=deepcopy(record)
    tokens=String.(split(observation.text))
    observation.motion===nothing || push!(tokens,"gesture:"*observation.motion)
    for token in unique(tokens)
        outcomes=get!(()->Dict{String,Int}(),memory.associations,(before,token))
        outcomes[after]=get(outcomes,after,0)+1
    end
    !isempty(tokens)
end

function role_predict(memory,context,token)
    outcomes=get(memory.associations,(context,token),Dict{String,Int}())
    total=sum(values(outcomes);init=0)
    total==0 && return (status="unknown",predicted=nothing,support=0.,samples=0)
    ranked=sort(collect(outcomes);by=p->(-p.second,p.first))
    support=first(ranked).second/total
    resolved=total>=TRADE_OBSERVATION.minimum_samples && support>=TRADE_OBSERVATION.minimum_share
    (status=resolved ? "provisional" : "ambiguous",predicted=resolved ? first(ranked).first : nothing,support=support,samples=total)
end

# Visible state descriptions, deliberately no "accepted"/"refused" oracle.
function role_visible_scene(w,observer,yaw,actor,description;attending=true)
    attending || return nothing
    sight=LW.social_sight(w,observer,yaw,0;illumination=1.)
    any(p->p["ref"]==actor,sight["peers"]) ? description : nothing
end
