# 暫定固定の既存ルール。値・条件は変えず、通常の身体限界とは別に保持する。
# 休息基準: 非MB経路・見学・scene.fatigue_forecast=falseの比較用に保持。
# MB通常移動は疲労見積もり比較へ移行。身体の実行限界とは別。
if !isdefined(@__MODULE__, :CONFIGURED_LIMITS)
    const CONFIGURED_LIMITS=(navigation_rest_strain=.8,negotiation_rounds=3,legacy_negotiation_rounds=8)
end
if !isdefined(@__MODULE__, :TASK_INTERRUPT_RULES)
    # Provisional, shared fixed attention policy, not hormones or learned values.
    # close_range: world distance, <= always re-observes; need_scale: anxiety units.
    # Weights dimensionless; zero need/progress retains the original sensor radius.
    const TASK_INTERRUPT_RULES=(close_range=2.,need_scale=1.,need_weight=1.,progress_weight=1.)
end
