# 暫定固定: scene.activity_capacity=false。作業/睡眠時間はSLEEP_REPAIR_LOCAL。
# 身体限界時は現地睡眠。将来は安全性・作業MBの予測で置換する。
# 修復材料は十分と仮定。栄養の追加引落しなし。
const CAPACITY_LW_RULES=(review_seconds=64.,records=128)
configured_capacity_state!(map)=get!(() -> D("mode"=>"active","next_us"=>0,"until_us"=>0,"decisions"=>D(),"records"=>Any[],"sleep_ticks"=>0),map,"activity_capacity_plan")
function configured_capacity_attach(body::HumanBody)
    body.activity_capacity!==nothing && return body
    HumanBody(body.burst,0.,body.damage,body.nutrients,body.hours_per_second,body.activity,
        ActivityCapacity.State(fatigue=body.strain,damage=body.damage),:observe)
end
function configured_capacity_sleep_start!(state,body,now,mode)
    state["mode"]=mode
    state["until_us"]=now+round(Int,SLEEP_REPAIR_LOCAL.field_sleep_hours/body.hours_per_second*1e6)
end
function configured_capacity_sleep_active!(map,body,now)
    state=configured_capacity_state!(map);capacity=body.activity_capacity
    capacity===nothing && return false
    # Hard physical stop can otherwise never reach a thinking tick to select sleep.
    if capacity.physical.wear>=1 && !(state["mode"] in ("sleep_here","sleep_then_home"))
        configured_capacity_sleep_start!(state,body,now,"sleep_here")
        state["forced_sleep"]=get(state,"forced_sleep",0)+1
    end
    if state["mode"] in ("sleep_here","sleep_then_home")
        now<state["until_us"] && return true
        state["mode"]=state["mode"]=="sleep_then_home" ? "home" : "active"
        state["next_us"]=now
    end
    false
end
function configured_capacity_request!(map,body,home,at_home,load,now,loop)
    state=configured_capacity_state!(map);capacity=body.activity_capacity
    capacity===nothing && return "active"
    configured_capacity_sleep_active!(map,body,now) && return state["mode"]
    if state["mode"]=="home" && at_home
        configured_capacity_sleep_start!(state,body,now,"sleep_here")
        return "sleep_here"
    end
    now<state["next_us"] && return state["mode"]
    seconds=at_home ? 0. : home===nothing ? FATIGUE_FORECAST_RULES.unknown_seconds : mb_travel_seconds(home["distance"])
    source=at_home ? "at_home" : home===nothing ? "bootstrap" : "observed"
    if !at_home && home===nothing && haskey(map,"daily_plan")
        estimate=mb_daily_estimate(map["daily_plan"],"return",seconds)
        seconds=estimate["seconds"];source=estimate["source"]
    end
    return_hours=seconds*body.hours_per_second
    effort=1+RDLBody.BODY_ACTION.load_effort*load
    projected=ActivityCapacity.forecast(capacity,SLEEP_REPAIR_LOCAL.work_hours,return_hours;effort)
    state["next_us"]=now+round(Int,CAPACITY_LW_RULES.review_seconds*1e6)
    if state["mode"]=="active" && ActivityCapacity.ratio(projected.work_home)<FATIGUE_FORECAST_RULES.onset
        return "active"
    end
    rules=merge(SLEEP_REPAIR_LOCAL,(horizon_hours=max(SLEEP_REPAIR_LOCAL.horizon_hours,return_hours+SLEEP_REPAIR_LOCAL.work_hours+SLEEP_REPAIR_LOCAL.field_sleep_hours),))
    choices=Any[]
    for method in ("continue","home","sleep_then_home","sleep_here")
        state["mode"]=="home" && method=="continue" && continue
        f=configured_sleep_repair_forecast(capacity,return_hours,method;rules,effort)
        f.feasible && push!(choices,D("method"=>method,"priority"=>f.priority,"question"=>"activity_recovery"))
    end
    choice_loop=get!(() -> BasicLoop("activity-capacity";probabilistic=true,seed=loop.seed),state,"loop")
    selection=choose_method!(choice_loop,choices,"capacity:$now")
    resolve_method!(choice_loop,"capacity:$now",nothing,nothing;creditable=false,goal_H_increment=0.)
    mode=selection["method"]
    state["decisions"][mode]=get(state["decisions"],mode,0)+1
    push!(state["records"],D("us"=>now,"choice"=>mode,"return_hours"=>return_hours,"source"=>source,
        "fatigue"=>capacity.fatigue,"capacity"=>ActivityCapacity.capacity(capacity),"wear"=>capacity.physical.wear))
    length(state["records"])>CAPACITY_LW_RULES.records && popfirst!(state["records"])
    state["mode"]=mode=="continue" ? "active" : mode
    if mode in ("sleep_here","sleep_then_home") || (mode=="home" && at_home)
        configured_capacity_sleep_start!(state,body,now,mode=="home" ? "sleep_here" : mode)
    end
    state["mode"]
end
function configured_capacity_sleep_tick!(map,w,a,counts,events,previous,now)
    state=configured_capacity_state!(map)
    state["sleep_ticks"]=get(state,"sleep_ticks",0)+1
    w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
    counts[a]["rest"]=get(counts[a],"rest",0)+1
    sig=("sleep","capacity_sleep")
    if get(previous,a,nothing)!=sig
        push!(events,D("us"=>now,"actor"=>a,"phase"=>"sleep","action"=>"rest","status"=>"performed",
            "method"=>"capacity_sleep","configured_rule"=>"activity_capacity","position"=>collect(w.positions[a])))
        previous[a]=sig
    end
end
