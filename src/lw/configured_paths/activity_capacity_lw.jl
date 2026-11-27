# 暫定固定: scene.activity_capacity=false。人の新身体・個人宅が必要。
# 作業1時間、現地休息30分、場所価値は局所試験の設定を使用する。
# 将来は作業MBの見込みへ置換。帰路は本人の観測/日次計画の学習から得る。
# 身体修復材料は現在は十分と仮定。食料の実消費を偽って加算しない。
const CAPACITY_LW_RULES=(work_hours=1.,review_seconds=64.,records=128,work_value=1.)
configured_capacity_state!(map)=get!(() -> D("mode"=>"active","next_us"=>0,"until_us"=>0,"decisions"=>D(),"records"=>Any[]),map,"activity_capacity_plan")
function configured_capacity_attach(body::HumanBody)
    body.activity_capacity!==nothing && return body
    HumanBody(body.burst,0.,body.damage,body.nutrients,body.hours_per_second,body.activity,
        ActivityCapacity.State(fatigue=body.strain,damage=body.damage),:observe)
end
function configured_capacity_request!(map,body,home,at_home,load,now,loop)
    state=configured_capacity_state!(map);capacity=body.activity_capacity
    capacity===nothing && return "active"
    if state["mode"]=="rest_home" && capacity.fatigue==0 && capacity.physical.wear==0
        state["mode"]="active";state["next_us"]=now
    end
    state["mode"]=="home" && at_home && (state["mode"]="rest_home")
    if state["mode"] in ("rest_then_home","rest_here")
        now<state["until_us"] && return state["mode"]
        state["mode"]=state["mode"]=="rest_then_home" ? "home" : "active"
    end
    state["mode"]!="active" && return state["mode"]
    now<state["next_us"] && return "active"
    seconds=at_home ? 0. : home===nothing ? FATIGUE_FORECAST_RULES.unknown_seconds : mb_travel_seconds(home["distance"])
    source=at_home ? "at_home" : home===nothing ? "bootstrap" : "observed"
    if !at_home && home===nothing && haskey(map,"daily_plan")
        estimate=mb_daily_estimate(map["daily_plan"],"return",seconds)
        seconds=estimate["seconds"];source=estimate["source"]
    end
    return_hours=seconds*body.hours_per_second
    effort=1+RDLBody.BODY_ACTION.load_effort*load
    projected=ActivityCapacity.forecast(capacity,CAPACITY_LW_RULES.work_hours,return_hours;effort)
    if ActivityCapacity.ratio(projected.work_home)<FATIGUE_FORECAST_RULES.onset
        state["next_us"]=now+round(Int,CAPACITY_LW_RULES.review_seconds*1e6)
        return "active"
    end
    horizon=max(RETURN_REST_RULES.horizon_hours,return_hours+RETURN_REST_RULES.pause_hours+CAPACITY_LW_RULES.work_hours)
    choices=configured_return_rest_candidates(capacity,return_hours;effort,horizon_hours=horizon)
    # Compare doing useful work first on the same evaluation horizon.
    work_body=deepcopy(capacity)
    ActivityCapacity.step!(work_body,:walk,CAPACITY_LW_RULES.work_hours;effort)
    after_work=configured_return_rest_forecast(work_body,return_hours,0.;effort,horizon_hours=horizon-CAPACITY_LW_RULES.work_hours)
    if after_work.feasible
        work_cost=CAPACITY_LW_RULES.work_hours*(configured_return_pressure(capacity)+configured_return_pressure(work_body))/2
        push!(choices,D("method"=>"continue","priority"=>CAPACITY_LW_RULES.work_value+body_demand(body)+after_work.priority-work_cost,"question"=>"activity_recovery"))
    end
    choice_loop=get!(() -> BasicLoop("activity-capacity";probabilistic=true,seed=loop.seed),state,"loop")
    selection=choose_method!(choice_loop,choices,"capacity:$now")
    resolve_method!(choice_loop,"capacity:$now",nothing,nothing;creditable=false,goal_H_increment=0.)
    mode=selection["method"]
    state["decisions"][mode]=get(state["decisions"],mode,0)+1
    push!(state["records"],D("us"=>now,"choice"=>mode,"return_hours"=>return_hours,"source"=>source,
        "fatigue"=>capacity.fatigue,"capacity"=>ActivityCapacity.capacity(capacity),"wear"=>capacity.physical.wear))
    length(state["records"])>CAPACITY_LW_RULES.records && popfirst!(state["records"])
    if mode=="continue"
        state["next_us"]=now+round(Int,CAPACITY_LW_RULES.work_hours/body.hours_per_second*1e6)
    else
        state["mode"]=at_home && mode=="home" ? "rest_home" : mode
        state["until_us"]=now+round(Int,RETURN_REST_RULES.pause_hours/body.hours_per_second*1e6)
    end
    state["mode"]
end
