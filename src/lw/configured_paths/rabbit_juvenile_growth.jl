# 暫定固定の成長近似。18〜28日で採食/消化/通常代謝を線形に増やす。
# 生存の抽選はしない。enabled=falseで従来の離乳一括切替。
# 巣からの行動半径0〜8、離乳後は無制限。移行中の泳ぎなし。
# 将来は身体成長・採食経験による発達へ置換。実測生存率ではない。
const RABBIT_JUVENILE_GROWTH=(enabled=true,start_days=18.,range_at_weaning=8.,burrow_radius=.25)
function configured_rabbit_growth(s,i,t)
    s.life===nothing && return nothing
    dependent(s.life,i,t) || return nothing
    r=RABBIT_JUVENILE_GROWTH
    age=(t-s.life.born[i])/RABBIT_LIFE.day_ticks
    fraction=r.enabled ? clamp((age-r.start_days)/(RABBIT_LIFE.wean_days-r.start_days),0.,1.) : 0.
    (fraction=fraction,nest=s.life.nest[i],radius=r.range_at_weaning*fraction,
     infant_cost=RABBIT_LIFE.infant_energy_per_day/RABBIT_LIFE.day_ticks)
end
configured_rabbit_self_feeding(s,i,t)=let g=configured_rabbit_growth(s,i,t);g===nothing || g.fraction>0 end
