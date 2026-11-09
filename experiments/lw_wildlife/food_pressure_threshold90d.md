# 親H閾値接続90日試験

2026-11-09起動。出力: C:/Users/ken_m/Documents/Codex/rabbit-food-threshold90d-20261109。
前回rabbit-local-rho90dと同じ新規世界条件、100兎・捕食者1・人なし、grass_scale=1.5、泳ぎあり、auto、diverse/patchy/distributed/layered。
変更は全兎への親H/選択閾値接続。開始1.0以上、解除0.5以下、履歴上限64。
最初の選択時の予備量が固定基準。試行ごとの更新・成長や授乳への基準適応は未実装であり長期の観察対象。
選択時のみ評価し、生のH/ゲートは非選択中に前回値を保持する。active集計を現在の空腹個体数と解釈しない。死亡個体の記憶も集計に含む。
設定経路はrabbit_food_pressure_experiment.jlに隔離、enabled=falseで接続前へ戻す。
将来は食料確保試行の学習見積もりに置換。通常接続の低H/開始/身体回復解除の検査PASS。
日次food_pressureにcalls/active_calls/active/peakHを保存、詳細はチェックポイント内の直近64イベント。
完了判定はジョブexit_code=0、completed.json verified=trueと90日を併せて確認する。起動時点では結果未確定。
