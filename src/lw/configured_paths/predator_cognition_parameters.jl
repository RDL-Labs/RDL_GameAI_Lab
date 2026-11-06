# 暫定設定: 動物単独 --cognition の初期係数・知識。既定OFF。
# 候補を強制選択せず人のBasicLoopへ渡す。位置記憶は自己位置の正確な積算を仮定。
# 狩猟/休息区間、短期予測の初期値は未較正。将来は身体・経験から更新する範囲を拡張。
const PREDATOR_COGNITION=(decision_ticks=60,episode_ticks=600,place_limit=16,single_rest_place=true,
    place_cell=8.,arrival_radius=3.,move_speed=.22,food_value_scale=900.,
    food_pressure_scale=600.,food_weight=3.,rest_weight=2.,rival_weight=2.,
    place_prior=.5,hunt_prior=.3,tolerance=.05,history_limit=64)
