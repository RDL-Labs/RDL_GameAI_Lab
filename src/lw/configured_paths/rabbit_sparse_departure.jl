# 暫定固定: 食べ尽くす前の採食離脱。既存の観測densityのみ使い追加走査しない。
# RabbitApproachPolicyのみ、既定ON。enabled=falseで移動加点だけの前版へ戻す。
# densityは植生の密度×残量比（遮蔽coverと異なり高さを含まない）。
# 閾値0.005〜0.05は実験用で実測値ではない。将来は採食成果のMB評価へ置換。
const RABBIT_SPARSE_DEPARTURE=(enabled=true,density_hungry=.005,density_comfortable=.05,
    reserve_low=25.,reserve_full=85.)
function configured_rabbit_sparse_state(state,o)
    p=RABBIT_SPARSE_DEPARTURE
    (!p.enabled || state!=GRAZE || o.vegetation===nothing) && return state
    slack=clamp((o.energy-p.reserve_low)/(p.reserve_full-p.reserve_low),0.,1.)
    threshold=p.density_hungry+(p.density_comfortable-p.density_hungry)*slack
    o.vegetation.density<threshold ? SEARCH : state
end
