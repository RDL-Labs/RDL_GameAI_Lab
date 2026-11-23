module ForecastDifferenceProbe

export ForecastDifference, observe_difference!, residual_h

# 本体未接続の局所共通部。入力は各MBが同じ尺度で評価した見込み・観測の増分。
# 個数・秒数・親子の種類を知らない。尺度化やρによる表現は呼出し側の責務。
mutable struct ForecastDifference
    expected::Float64
    observed::Float64
    receipts::Set{Int}
end
ForecastDifference() = ForecastDifference(0., 0., Set{Int}())
residual_h(state::ForecastDifference) = max(0., state.expected - state.observed)

function observe_difference!(state::ForecastDifference, receipt::Int, expected, observed)
    receipt in state.receipts && return false
    # 未観測は不成果ゼロと区別する。評価可能になるまで両側の登録を保留する。
    (expected === nothing || observed === nothing) && return false
    all(x -> x isa Real && !(x isa Bool) && isfinite(x) && x >= 0,
        (expected, observed)) || throw(ArgumentError("invalid forecast/observation"))
    next_expected = state.expected + Float64(expected)
    next_observed = state.observed + Float64(observed)
    all(isfinite, (next_expected, next_observed)) || throw(ArgumentError("overflow"))
    push!(state.receipts, receipt)
    state.expected = next_expected
    state.observed = next_observed
    true
end
end
