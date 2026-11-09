# 暫定固定の親H局所実験。通常未接続、対象個体はランナーで指定。
# 探索開始時のenergy+3*gutを基準に固定予算120 SEARCH tick相当の1.44を許容。
# それ以上の未回復分/4を親Hとする。局所到着では消さない。
# 胃内容は消化見込みとして計上。生存抽選や経路禁止なし。
# 将来は食料確保MBの学習見積もり/身体要求へ置換。
const RABBIT_FOOD_PRESSURE=(forecast_ticks=120,search_cost=.012,residual_scale=4.,H_limit=32.,gut_conversion=3.)
mutable struct RabbitFoodPressure
    expected::Union{Nothing,Float64}
    H::Float64
    peak::Float64
    records::Vector{Any}
end
RabbitFoodPressure()=RabbitFoodPressure(nothing,0.,0.,Any[])
# 暫定固定の選択ゲート。通常未接続。H>=1で開始、H<=0.5で解除。
# 生のHは保持し、非活動時のみ選択へ渡す圧を0にする。
# 将来は目的・経験に応じた許容帯へ置換。enabled=falseで旧H>0方式。
const RABBIT_FOOD_PRESSURE_GATE=(enabled=true,enter_H=1.,exit_H=.5)
mutable struct RabbitFoodPressureGate
    active::Bool
    calls::Int
    active_calls::Int
    records::Vector{Any}
end
RabbitFoodPressureGate()=RabbitFoodPressureGate(false,0,0,Any[])
function configured_food_pressure_gate!(gate,pressure,t;settings=RABBIT_FOOD_PRESSURE_GATE)
    gate.calls+=1
    settings.enabled || return pressure
    previous=gate.active
    gate.active=gate.active ? pressure>settings.exit_H : pressure>=settings.enter_H
    gate.active_calls+=gate.active
    if previous!=gate.active
        push!(gate.records,(tick=t,active=gate.active,H=pressure))
    end
    gate.active ? pressure : 0.
end
function configured_food_pressure!(m,a,i,t)
    p=RABBIT_FOOD_PRESSURE;reserve=a.energy[i]+p.gut_conversion*a.gut[i]
    if m.expected===nothing
        m.expected=reserve-p.forecast_ticks*p.search_cost
        push!(m.records,(event="forecast",tick=t,reserve=reserve,expected=m.expected))
    end
    m.H=clamp((m.expected-reserve)/p.residual_scale,0.,p.H_limit)
    if m.H>m.peak+.1
        push!(m.records,(event="pressure",tick=t,H=m.H,reserve=reserve))
    end
    m.peak=max(m.peak,m.H)
    m.H
end
