# 動く危険物体と既存生活・経路の有限比較

2026-10-03。基準main `4c9d322` + 本変更。軽量Python Worldで実行。Luanti/Godot/HTTPは未実行。
[契約](../experiment-contracts/LW_moving_hazard_safety_contract.md)。

## 結果

seed20261001、A/B/C、無限資源、帰還3回停止なし、左癖、関係移動場・経路記憶・局所目標H等を同条件で有効化。
5日比較5runと1日補助2run、合計7run・27シミュレーション日。

|条件|日数|採取|配送 A/B/C|限定解除|終了時|
|---|---:|---:|---|---:|---|
|disabled|5|194|46/87/61|—|通常|
|shadow crossing|5|194|46/87/61|診断のみ|行動はdisabledと同一|
|enabled crossing|5|28|0/28/0|1|全員unresolved|
|shadow route_crossing|5|194|46/87/61|診断のみ|行動はdisabledと同一|
|enabled route_crossing|5|180|46/82/52|2|全員normal|
|enabled night|1|74|0/28/23|0|全員review、Aは23携行|
|enabled persistent|1|66|0/28/15|1|全員normal、Aは23携行|

route_crossingは初日を危険なしで走らせる。disabled/shadow/enabledの初日command列は完全一致。その後のWorld座標で固定した横断を使う。成功地点に追従するhazardではない。
Bは135.25秒に待機、138秒に見回し、139秒に解除。Cは263.5秒に待機、266秒に見回し、267秒に解除。現在条件から通常判断を再開し、保存モデル・経路を消さず配送を継続した。
分岐snapshotの直接複製ではなく、同じ初期条件から再実行して初日一致を検査した比較。

crossingでは退避step3判断・安全旋回/見回し103判断が選ばれたが、遮蔽による取得不完了などで最終的に全個体がunresolvedとなった。観測と理由記録は続くが、新しい退避候補を無限に作らないため保留が残る。採取改善・停滞解消・安全性達成は主張しない。

World監査の距離<=1サンプル数はshadow crossing15、enabled crossing44、route_crossing両側0、night4、persistent2。これは離散時点の近接回数で、独立した接触事件数や連続衝突・負傷ではない。少なくとも今回の結果から危険回避性能の改善は結論できない。

## 検査

専用17 + 既存関連65 = **82 tests PASS**。全体suiteは未実行。
身体結果対応、partial非解除、空観測と解除の区別、操作上限、確認用の後半予算、goalのdefer/実成功、割込み前blocked保持、経路支持保護、観測再送・身体一回実行を検査。

全ログ監査でsource束縛、32操作上限、安全phaseでの採取禁止、trialの割込み印、保存経路support/Hの非誤帰属、完走時刻、同操作の重複完了なしをassert。
shadowの全command列はdisabledと一致。危険下でも既存の食料成功・配送を削除していない。
結果は[集計JSON](../../tests/fixtures/lightweight_moving_hazard.json)に保存。raw JSONLはignored output内、SHA-256・manifest・summary・mode遷移を同梱。集計は元ログの監査結果であり、このJSON単独でセンサー/Worldを再実行したことにはならない。

## 再実行

リポジトリrootから実行する。各組のmode/scenario/daysを表どおり変える。

```powershell
py -3.11 -m integrations.lightweight.timed_harvest --output integrations/lightweight/output/hazard_enabled_route_crossing.jsonl --days 5 --seed 20261001 --skyline-subrays --inexhaustible --no-return-target --mb-field-mode enabled --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled --return-completion-mode enabled --nested-model-mode enabled --directional-route-mode enabled --relation-field-mode enabled --hazard-mode enabled --hazard-scenario route_crossing
py -3.11 -m integrations.lightweight.audit_moving_hazard
py -3.11 -m unittest tests.test_moving_hazard_safety tests.test_route_weight tests.test_relational_movement tests.test_directional_routes tests.test_food_revisit tests.test_nested_local_models tests.test_local_return tests.test_timed_harvest tests.test_incomplete_reposition
```

監査用ファイル名: `hazard_disabled_5d.jsonl`、`hazard_{shadow|enabled}_{crossing|route_crossing}.jsonl`、`hazard_enabled_night.jsonl`、`hazard_enabled_persistent.jsonl`。
当初の16操作上限から、確認枠を残す32操作へ変更した試作を経て最終比較を再実行した。初期の遮蔽未考慮の結果を最終結果へ混ぜていない。係数探索による一般的な優位性の実証ではない。

## 残件

S1/S2の有限接続とS3の先行比較まで。S4複数seed・長期は未実施。未解決からの新しい候補、採取中キャンセル、危険固有のE/H学習、感情合成、動的解像度は後続契約。既存Observation v1の完了を変更しない。
