# 暫定認知係数。RabbitApproachPolicyを明示指定したときだけON（既定は旧FSM）。
# 自己位置と近傍セル観測を用いる既存ショートカットを継続。
# 将来は距離/時間見積もりを経験とρへ接続する。強制脱出/目標禁止はしない。
const RABBIT_APPROACH=(speed=.2,minimum_ticks=10,distance_band=.25,
    H_limit=32.,temperature_scale=2.,memory_limit=64,history_limit=64)
