# 暫定固定: 移動候補の草の濃さを加点。採食を切り上げる作用は持たせない。
# RabbitApproachPolicyのみ適用、既定ON、enabled=falseで従来挙動。新しい世界探索はしない。
# 将来は露出・採食経験のMB評価へ置換。各値は生物学的測定値ではない。
const RABBIT_COVER_FORAGING=(enabled=true,reserve_low=25.,reserve_full=85.,
    cover_target_weight=2.)
function configured_rabbit_cover_slack(energy)
    p=RABBIT_COVER_FORAGING
    clamp((energy-p.reserve_low)/(p.reserve_full-p.reserve_low),0.,1.)
end
configured_rabbit_observed_cover(o)=o.vegetation===nothing ? 0. : clamp(o.vegetation.cover,0.,1.)
function configured_rabbit_cover_bonus(o,energy)
    p=RABBIT_COVER_FORAGING
    p.enabled ? p.cover_target_weight*configured_rabbit_cover_slack(energy)*configured_rabbit_observed_cover(o) : 0.
end
