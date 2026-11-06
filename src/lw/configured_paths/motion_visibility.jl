# 暫定感覚モデル。motion_speed=false（既定）は従来二値、trueで連続速度係数。
# 単位は距離/tick。静止0.55、速度0.5で1に飽和する初期値で、生物学的較正値ではない。
# 対象の前tick実変位を用いる。指令速度や未観測の将来位置は用いない。
# 追跡済みなら1を維持。将来は網膜上の動き・観測間隔・経験差を扱う共通感覚へ置換。
const MOTION_VISIBILITY=(stationary=.55,saturation_speed=.5)
function configured_motion_visibility(displacement,tracked)
    tracked && return 1.
    rule=MOTION_VISIBILITY
    rule.stationary+(1-rule.stationary)*clamp(displacement/rule.saturation_speed,0.,1.)
end
