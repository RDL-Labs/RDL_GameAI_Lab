# API experiment adapter: candidate generation, continuation and reconsideration remain
# ordinary LW. Only selection at the normal choose_method! boundary is delegated.
const CONFIGURED_API_NAV_REPORT_US=600_000_000 # diagnostic aggregation, never motion timing
const CONFIGURED_API_NAV=Dict{String,Any}()
function configured_api_nav_result!(actor,action,status,now)
    actor==CONFIGURED_API_AGENT.actor || return
    outcomes=get!(() -> Dict{String,Int}(),CONFIGURED_API_NAV,"outcomes")
    key=action*":"*status;outcomes[key]=get(outcomes,key,0)+1
end
function configured_api_nav_flush!(now)
    outcomes=get!(() -> Dict{String,Int}(),CONFIGURED_API_NAV,"outcomes")
    isempty(outcomes) && return
    configured_api_record!((event="self_action_outcomes",us=now,ticks=copy(outcomes)))
    empty!(outcomes)
end
function configured_api_nav_projection(candidate,yaw)
    haskey(candidate,"direction") || return nothing
    angle=Float64(get(candidate,"steering_angle",ANGLES[candidate["direction"]+1]))
    (relative_degrees=angle,heading_degrees=mod(yaw+angle,360))
end
function configured_api_candidate_belief(c,loop)
    # Owner-local estimates/experience, not objective success or other actors' state.
    keys=("method","question","priority","expected","cue_kind","cue_angle","cue_distance",
        "mb_parent_estimate","mb_return_outlook","mb_expected","mb_route","mb_edge",
        "goal_arrival","goal_alignment","mb_parent_goal")
    belief=Dict(k=>deepcopy(c[k]) for k in keys if haskey(c,k))
    node=get(loop.methods,c["method"],nothing)
    node===nothing || (belief["method_experience"]=(H=node.H,reward=node.reward,failures=node.failure_count))
    belief
end
function configured_api_navigation!(actor,loop,candidates,source,body,stock,now,yaw,landmarks;
        navigation_context=nothing,budget_capture=nothing,selector=configured_api_choose!)
    actor==CONFIGURED_API_AGENT.actor || return choose_method!(loop,candidates,source)
    isempty(candidates) && return choose_method!(loop,candidates,source)
    configured_api_nav_flush!(now)
    day=div(now,17_280_000_000)+1
    if get(CONFIGURED_API_CALLS,day,0)>=CONFIGURED_API_AGENT.calls_per_day || sum(values(CONFIGURED_API_CALLS);init=0)>=CONFIGURED_API_AGENT.total_calls
        configured_api_budget_stop!(now,budget_capture)
    end
    options=deepcopy(candidates)
    for c in options
        c["api_movement"]=configured_api_nav_projection(c,yaw)
        c["api_belief"]=configured_api_candidate_belief(c,loop)
    end
    view=Dict{String,Any}("navigation"=>(heading=yaw,observed_landmarks=landmarks,
        context=navigation_context,own_H=loop.H,continuation="ordinary LW gradient_roll and MB lifecycle"))
    plan=selector(loop,options,source,Dict("actor"=>actor),view,body,stock,now)
    expression=get(CONFIGURED_API_EXPRESSIONS,Int(now),nothing)
    expression===nothing || (CONFIGURED_API_EXPRESSIONS[Int(now)]=merge(expression,(action="continue",)))
    plan
end
