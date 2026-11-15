# 暫定固定: 食料探索なしの生活実験。configured_trade_living は既定false。
# 食事・加工・応答・取引の既存判断後に残った探索枠だけを待機に置換する。
# 正解状態の照合や取引の強制はしない。将来は本人の生活計画MBへ置換する。
# 記録はmethod/configured_rule=trade_living_wait。実験開始位置は拠点内。
function configured_trade_living_wait(enabled)
    enabled || return nothing
    D("action"=>"rest","method"=>"trade_living_wait","configured_rule"=>"trade_living_wait")
end
