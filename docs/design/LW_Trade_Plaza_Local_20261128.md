# 取引広場の局所検査

2026-11-28。基準HEAD 37f3fa7。通常LWへの接続・長期実験は未実施。

## 暫定設定と範囲

全員が広場を知っている設定を `configured_paths/trade_plaza_local.jl` に隔離。
通常LWではincludeしないため既定OFF。実験から明示includeして有効化する。
広場中心は呼出側指定、到着半径は `TRADE_PLAZA_LOCAL_RULES.arrival_radius=0.5`。
集合後は既存social_sightの相手の方角を使って接近し、既存trade_partnersに
相手が入ったら接近を終了する。未視認・進行不能はscan。所有物や取引価値は変更しない。
将来は広場の知識と集合を関係MB・合流計画へ置換する。

## 結果

`experiments/social_relationships/trade_plaza_local_checks.jl` をJulia 1.13.1、1threadで実行。
追加104項目、既存の呼びかけ検査110項目、合計214 PASS。
拠点中心(0,0)、相手同士(0,1.1)/(0,-1.1)の対向配置では旧接近処理は双方停止し接触不可。
新しい局所処理は8シードとも合計2歩（各1歩）で接触し、既存の交渉評価1回へ到達した。
移動は既存movement_observationの候補・身体stepで距離を計算し、局所ハーネスで座標を更新。
通常day executor全体ではない。交渉評価だけでは所有物が移動しないことも確認。
広場内の相手方角による接近、未視認scan、移動候補なしscanは別入力で検査。

交換成立を強制した検査ではなく、交渉に入れなかった幾何条件の検査である。
通常の食事・加工による中断、期限切れ、障害物の迂回、複数組の混雑、scanの実行と
再視認の循環、実際のC/A保存状態からの日再実行は未検証。

実行：`julia --startup-file=no --threads=1 --project=. experiments/social_relationships/trade_plaza_local_checks.jl`
