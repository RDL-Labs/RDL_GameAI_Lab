# 暫定固定: API探索実験のみ。600秒ごとの選択、途中は同じ候補の継続。
# 候補消失時は休止し、通常MBへの黙った代行はしない。衝突・代謝は世界側。
# 将来は観測された変化に基づく自律的な再確認へ置換する。
const CONFIGURED_API_NAV_INTERVAL_US=600_000_000
const CONFIGURED_API_NAV=Dict{String,Any}()
function configured_api_nav_result!(actor,action,status,now)
    actor==CONFIGURED_API_AGENT.actor || return
    outcomes=get!(() -> Dict{String,Int}(),CONFIGURED_API_NAV,"outcomes")
    key=action*":"*status;outcomes[key]=get(outcomes,key,0)+1
    if now>=get(CONFIGURED_API_NAV,"report_us",0)
        configured_api_record!((event="self_action_outcomes",us=now,ticks=copy(outcomes)))
        empty!(outcomes);CONFIGURED_API_NAV["report_us"]=now+CONFIGURED_API_NAV_INTERVAL_US
    end
end
function configured_api_nav_projection(candidate,yaw)
    haskey(candidate,"direction") || return nothing
    angle=Float64(get(candidate,"steering_angle",ANGLES[candidate["direction"]+1]))
    (relative_degrees=angle,heading_degrees=mod(yaw+angle,360))
end
function configured_api_navigation!(actor,loop,candidates,source,body,stock,now,yaw,landmarks)
    actor==CONFIGURED_API_AGENT.actor || return choose_method!(loop,candidates,source)
    options=deepcopy(candidates)
    for c in options;c["api_movement"]=configured_api_nav_projection(c,yaw);end
    wait=Dict{String,Any}("action"=>"rest","method"=>"api_navigation_wait","priority"=>0.)
    push!(options,wait)
    if now<get(CONFIGURED_API_NAV,"next_us",0)
        method=get(CONFIGURED_API_NAV,"method","")
        selected=findfirst(c->c["method"]==method,options)
        if startswith(method,"step_") && haskey(CONFIGURED_API_NAV,"heading")
            steps=filter(c->startswith(c["method"],"step_") && c["api_movement"]!==nothing,options)
            if !isempty(steps)
                delta(c)=abs(mod(c["api_movement"].heading_degrees-CONFIGURED_API_NAV["heading"]+180,360)-180)
                best=steps[argmin(delta.(steps))]
                return choose_method!(loop,[delta(best)<=15 ? best : wait],source)
            end
        end
        return choose_method!(loop,[selected===nothing ? wait : options[selected]],source)
    end
    day=div(now,17_280_000_000)+1
    if get(CONFIGURED_API_CALLS,day,0)>=CONFIGURED_API_AGENT.calls_per_day || sum(values(CONFIGURED_API_CALLS);init=0)>=CONFIGURED_API_AGENT.total_calls
        return choose_method!(loop,[wait],source)
    end
    # Landmarks is already the observer's sensor projection, never world objects.
    view=Dict{String,Any}("navigation"=>(heading=yaw,observed_landmarks=landmarks,confirmation_seconds=600))
    plan=configured_api_choose!(loop,options,source,Dict("actor"=>actor),view,body,stock,now)
    CONFIGURED_API_NAV["next_us"]=now+CONFIGURED_API_NAV_INTERVAL_US
    CONFIGURED_API_NAV["method"]=plan["method"]
    movement=get(plan,"api_movement",nothing)
    movement===nothing || (CONFIGURED_API_NAV["heading"]=movement.heading_degrees)
    # Emit navigation speech through the same hearing/MB path as idle speech.
    expression=get(CONFIGURED_API_EXPRESSIONS,Int(now),nothing)
    expression===nothing || (CONFIGURED_API_EXPRESSIONS[Int(now)]=merge(expression,(action="continue",)))
    plan
end
