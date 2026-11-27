# 暫定固定・局所専用。通常LW未接続。35%は早期負担評価の試験基準であり停止閾値ではない。
# 栄養条件は同一として身体消耗のみ比較。将来は栄養・身体・行程MBの共通予測に統合。
const BODY_APPRAISAL_LOCAL=(reference_wear=.35,late_reference=1.)
function configured_body_appraisal(body;reference=BODY_APPRAISAL_LOCAL.reference_wear)
    isfinite(reference) && reference>0 || throw(ArgumentError("appraisal reference"))
    ((1-ActivityCapacity.capacity(body))/reference)^2
end
function configured_body_appraisal_candidates(body,hours;reference=BODY_APPRAISAL_LOCAL.reference_wear,rules=SLEEP_REPAIR_LOCAL)
    choices=Any[]
    for method in ("continue","home","sleep_then_home","sleep_here")
        f=configured_sleep_repair_forecast(body,hours,method;rules,
            pressure=b->configured_body_appraisal(b;reference),burden=b->1-ActivityCapacity.capacity(b))
        f.feasible && push!(choices,D("method"=>method,"priority"=>f.priority,"question"=>"activity_recovery"))
    end
    choices
end
