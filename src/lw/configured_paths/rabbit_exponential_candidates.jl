include("../../common/relational_expansion.jl")
# 暫定固定の候補幅。学習した強度の代わりに既存の草/距離/方向/失敗Hを粗順位に使用。
# 前半を抑える指数3、H20で最大8候補。将来は共通MBの関係想起へ置換。
# enabled=falseで旧ゲート方式。近傍観測/通行確認の削減は含まない。
const RABBIT_EXPONENTIAL_CANDIDATES=(enabled=true,minimum=1,maximum=8,full_H=20.,curvature=3.)
const RABBIT_CANDIDATE_STATS=Dict("calls"=>0,"available"=>0,"evaluated"=>0,"single"=>0)
function configured_rabbit_candidate_count(pressure,available;settings=RABBIT_EXPONENTIAL_CANDIDATES)
    available<=0 && return 0
    upper=min(available,settings.maximum)
    lower=min(upper,settings.minimum)
    fraction=relational_expansion_fraction(pressure;full_H=settings.full_H,curvature=settings.curvature)
    clamp(round(Int,lower+(upper-lower)*fraction),lower,upper)
end
function configured_rabbit_candidate_choice(observations,a,i,m,pressure,temperature_scale)
    n=configured_rabbit_candidate_count(pressure,length(observations))
    # 粗順位には最新観測と既存の局所Hのみ。隠れた餌場や正解経路は参照しない。
    rough=[o.grass-.25o.distance+.2cos(o.direction-a.heading[i])-
           (o.cell==a.previous_cell[i] ? 1. : 0.)-get(m.H,o.cell,0.) for o in observations]
    indices=partialsortperm(rough,1:n;rev=true)
    RABBIT_CANDIDATE_STATS["calls"]+=1
    RABBIT_CANDIDATE_STATS["available"]+=length(observations)
    RABBIT_CANDIDATE_STATS["evaluated"]+=n
    RABBIT_CANDIDATE_STATS["single"]+=(n==1)
    n==1 && return first(indices)
    scores=[rough[j]+configured_rabbit_cover_bonus(observations[j],a.energy[i]) for j in indices]
    weights=exp.((scores.-maximum(scores))./(1+pressure/temperature_scale))
    draw=rand(m.rng)*sum(weights)
    for (j,weight) in zip(indices,weights)
        draw-=weight
        draw<=0 && return j
    end
    last(indices)
end
