# 暫定固定の休息場所効用。通常LW未接続・既定OFF（局所から明示include）。
# 観測/記憶された制御火の安全度・熱距離だけを受け取る。全Hを冷却せず、
# 集合・取引を強制しない。将来は暖かさ等の身体評価と場所MB経験で置換。
# 距離は世界単位、gainはlog-weight。最大0.4なら単独オッズ倍率exp(.4)。
const FIRE_REST_LOCAL_RULES=(gain=0.4,comfortable_distance=2.0,width=1.5,hot_distance=1.2,heat_penalty=2.0)
function configured_fire_rest_bias(distance,safety;enabled=false,rules=FIRE_REST_LOCAL_RULES)
    enabled || return 0.0
    distance===nothing && return 0.0 # 未観測を距離ゼロにしない
    isfinite(distance) && distance>=0 || throw(ArgumentError("fire distance"))
    0<=safety<=1 || throw(ArgumentError("fire safety"))
    comfort=max(0.,1-((distance-rules.comfortable_distance)/rules.width)^2)
    heat=max(0.,1-distance/rules.hot_distance)^2
    rules.gain*safety*comfort-rules.heat_penalty*heat
end
