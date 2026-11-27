# 暫定固定・局所専用。通常LW未接続。距離は入力された所要時間見積もりで表す。
# 自宅の安全価値・現地休息時間は試験設定。将来は場所MBと行程MBから取得する。
# 疲労容量超過は連続費用。身体能力0だけを実行不能とする。
const RETURN_REST_RULES=(step_hours=.05,overload_gain=4.,home_value=.8,
    field_cost=.2,delay_cost=.25,recovery_gain=1.,pause_hours=.5,horizon_hours=4.)
function configured_return_pressure(body;rules=RETURN_REST_RULES)
    ratio=ActivityCapacity.ratio(body)
    isfinite(ratio) ? ratio^2+rules.overload_gain*max(0.,ratio-1)^2+body.physical.wear^2 : Inf
end
function configured_return_rest_forecast(body,return_hours,pause_hours;
        effort=1.,home_value=RETURN_REST_RULES.home_value,field_cost=RETURN_REST_RULES.field_cost,
        horizon_hours=RETURN_REST_RULES.horizon_hours,rules=RETURN_REST_RULES)
    all(isfinite,(return_hours,pause_hours,effort,home_value,field_cost,horizon_hours)) &&
        min(return_hours,pause_hours,effort,home_value,field_cost)>=0 &&
        return_hours+pause_hours<=horizon_hours || throw(ArgumentError("return scenario"))
    predicted=deepcopy(body);walk_cost=0.;max_ratio=ActivityCapacity.ratio(body)
    # Equal evaluation horizon for both plans: pause + walk + home recovery.
    ActivityCapacity.step!(predicted,:rest,pause_hours)
    remaining=return_hours
    while remaining>0
        ActivityCapacity.capacity(predicted)>0 || return (feasible=false,priority=nothing,body=predicted,max_ratio=max_ratio)
        dt=min(rules.step_hours,remaining)
        before=configured_return_pressure(predicted;rules)
        ActivityCapacity.step!(predicted,:walk,dt;effort)
        ActivityCapacity.capacity(predicted)>0 || return (feasible=false,priority=nothing,body=predicted,max_ratio=Inf)
        walk_cost+=dt*(before+configured_return_pressure(predicted;rules))/2
        max_ratio=max(max_ratio,ActivityCapacity.ratio(predicted))
        remaining=max(0.,remaining-dt)
    end
    home_hours=horizon_hours-return_hours-pause_hours
    ActivityCapacity.step!(predicted,:sleep,home_hours)
    # Reward reduction of the original burden, never the extra wear we just created.
    initial=body.fatigue+body.physical.wear
    recovery=max(0.,initial-predicted.fatigue-predicted.physical.wear)
    priority=home_value*home_hours+rules.recovery_gain*recovery-walk_cost-
        field_cost*pause_hours-rules.delay_cost*(return_hours+pause_hours)
    (feasible=true,priority=priority,body=predicted,max_ratio=max_ratio,
        walk_cost=walk_cost,home_hours=home_hours,recovery=recovery)
end
function configured_return_rest_candidates(body,return_hours;kwargs...)
    candidates=Any[]
    for (method,pause) in (("home",0.),("rest_then_home",RETURN_REST_RULES.pause_hours))
        forecast=configured_return_rest_forecast(body,return_hours,pause;kwargs...)
        forecast.feasible || continue
        push!(candidates,D("method"=>method,"priority"=>forecast.priority,"question"=>"activity_recovery",
            "max_ratio"=>forecast.max_ratio,"walk_cost"=>forecast.walk_cost,"home_hours"=>forecast.home_hours))
    end
    isempty(candidates) && push!(candidates,D("method"=>"rest_here","priority"=>0.,"question"=>"activity_recovery"))
    candidates
end
