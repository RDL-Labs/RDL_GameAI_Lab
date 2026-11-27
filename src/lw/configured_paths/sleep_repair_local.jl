# 暫定固定・局所専用、通常LW未接続。帰路時間は入力見積もり。
# 作業1生活時間と効用4、現地睡眠1時間、評価期間6時間は比較用。
# 将来は行程MBの時間・成果・場所の安全見込みへ置換する。
const SLEEP_REPAIR_LOCAL=(work_hours=1.,work_value=4.,field_sleep_hours=1.,horizon_hours=6.,step_hours=.05)
const SLEEP_REPAIR_WEAR=merge(ActivityWear.RULES,(rest_per_hour=0.,))
function configured_sleep_repair_forecast(body,return_hours,method;rules=SLEEP_REPAIR_LOCAL,effort=1.)
    isfinite(return_hours) && return_hours>=0 || throw(ArgumentError("return hours"))
    predicted=deepcopy(body);cost=0.;elapsed=0.;benefit=0.
    steps=method=="continue" ? ((:walk,rules.work_hours),(:walk,return_hours)) :
          method=="home" ? ((:walk,return_hours),) :
          method=="sleep_then_home" ? ((:sleep,rules.field_sleep_hours),(:walk,return_hours)) :
          method=="sleep_here" ? () : throw(ArgumentError("method"))
    sum((s[2] for s in steps);init=0.)<=rules.horizon_hours || throw(ArgumentError("horizon"))
    for (action,hours) in steps
        remaining=hours
        while remaining>0
            dt=min(remaining,rules.step_hours)
            if action==:walk
                ActivityCapacity.capacity(predicted)>0 || return (feasible=false,priority=nothing,body=predicted)
                before=configured_return_pressure(predicted)
                ActivityCapacity.step!(predicted,action,dt;wear_rules=SLEEP_REPAIR_WEAR,effort)
                ActivityCapacity.capacity(predicted)>0 || return (feasible=false,priority=nothing,body=predicted)
                cost+=dt*(before+configured_return_pressure(predicted))/2
            else
                ActivityCapacity.step!(predicted,action,dt;wear_rules=SLEEP_REPAIR_WEAR)
            end
            elapsed+=dt;remaining=max(0.,remaining-dt)
        end
    end
    home_hours=method=="sleep_here" ? 0. : max(0.,rules.horizon_hours-elapsed)
    ActivityCapacity.step!(predicted,:sleep,max(0.,rules.horizon_hours-elapsed);wear_rules=SLEEP_REPAIR_WEAR)
    recovery=max(0.,body.fatigue+body.physical.wear-predicted.fatigue-predicted.physical.wear)
    benefit=method=="continue" ? rules.work_value : 0.
    priority=benefit+RETURN_REST_RULES.home_value*home_hours+recovery-cost-RETURN_REST_RULES.delay_cost*elapsed
    (feasible=true,priority=priority,body=predicted)
end
