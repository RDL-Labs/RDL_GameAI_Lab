# 暫定固定: 既存の草観測と身体reserveから遮蔽/採食を評価する。
# RabbitApproachPolicyのみ適用、enabled=falseで従来挙動。新しい世界探索はしない。
# 将来は露出・採食経験のMB評価へ置換。各値は生物学的測定値ではない。
const RABBIT_COVER_FORAGING=(enabled=false,reserve_low=25.,reserve_full=85.,
    cover_target_weight=2.,exposure_weight=1.,intake_scale=.025)
function configured_rabbit_cover_slack(energy)
    p=RABBIT_COVER_FORAGING
    clamp((energy-p.reserve_low)/(p.reserve_full-p.reserve_low),0.,1.)
end
configured_rabbit_observed_cover(o)=o.vegetation===nothing ? 0. : clamp(o.vegetation.cover,0.,1.)
function configured_rabbit_cover_state(state,o)
    p=RABBIT_COVER_FORAGING
    (!p.enabled || o.vegetation===nothing || state!=GRAZE) && return state
    # Current food benefit competes with exposure; urgent hunger suppresses exposure.
    food=o.grass/(o.grass+p.intake_scale)
    exposure=p.exposure_weight*configured_rabbit_cover_slack(o.energy)*(1-configured_rabbit_observed_cover(o))
    food<exposure ? SEARCH : state
end
function configured_rabbit_cover_bonus(o,energy)
    p=RABBIT_COVER_FORAGING
    p.enabled ? p.cover_target_weight*configured_rabbit_cover_slack(energy)*configured_rabbit_observed_cover(o) : 0.
end
