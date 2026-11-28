# 焚火休息・通常LW 10日

## 宣言した暫定接続

scene.fire_rest=false既定。trueで既存の自宅休息選択入口に焚火休息を追加。
`configured_paths/fire_rest.jl`へ隔離。拠点中央の安全な焚火を知る初期知識を仮定。
観測から場所を覚える処理、市場形成の学習は未接続。明示的な集合・取引は強制しない。
自宅と火周囲の効用を距離費用込みで確率比較し、火を選ぶと半径2の近い側へ歩き休む。
局所モデルと違い現在地という独立候補は設けず、既存自宅休息への代替候補として接続。
夜間、身体要求>.35、既存の未決処理・呼びかけ起床・予定行動は火休息を抑制。
高レベル認知停止は火周囲には追加しないため、自宅休息より処理時間が増える可能性がある。

FIRE_REST_RULES: review_us=128000000、travel_cost=.12、home_value=.2、arrival=.48。
既存FIRE_REST_LOCAL_RULESのgain=.4、安全度1で比較。専用RNGはchoice_seed+個体順から作成し保存。
途中の別目的行動は優先される。到着不能への学習や安全度の学習はこの変更に含めない。
記録はmb_maps.configured_fire_restと日別physical.fire_rest（RNGを除外）、行動event.method。

## 実行条件

初期から10日、人4体、動物OFF、既存研修・取引・個人宅・栄養40・歩行消耗1%条件。
直近human-food40-wear1-10-20261128のinputへscene.fire_rest=trueのみ追加。
Julia1.13.1、1thread、凍結ソース・日末保存あり。
出力：`C:/Users/ken_m/Documents/Codex/human-fire-rest-10-20261128`。
タスク：RDL-Julia-a2f32c9017ed4fa39482bfce98dcd977。
局所接続ゲート検査5PASS。10日試験は起動段階、完了・効果は未判定。
完了後に休息選択・滞在tick、取引、身体状態、実時間を確認する。
この入口が選ばれない場合も、そのまま集まったと報告しない。
