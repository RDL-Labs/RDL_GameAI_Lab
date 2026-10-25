# 初日見回し＋通常探索3日

2026-10-25。[設定経路の設計](../../docs/design/LW_Initial_Home_Observation.md)。狭い入口・分岐道・seed=20261005、身体目的・共通睡眠・MB地図・まとまりON。home_observation=onを追加し、計4日実行。

## フェーズの実行

4日正常完走、実行314.92秒（約5分15秒、コンパイル込み）、ピークRSS 1,281,609,728 bytes（約1.28GB）。序盤に既存MB検査を並行したため厳密な速度比較には使わない。

初日は全員17280tickを観察フェーズとして記録し、入口通過0。開始位置からの最大変位は全員0.8。夜の休息は全員2880tick。全員2日目に外へ出た（開始からB18088秒、C18376秒、A19006秒）。強制観察のイベントは初日だけで、翌日以降の通常歩行も確認した。

| 個体 | 初日の旋回 / 歩行 | 有効な地図観測 | 初日末ノード / 辺 | homeラベル | 初日末reserve |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 14176 / 224 | 2215 | 4 / 1 | 0 | 11.08 |
| B | 14176 / 223 | 3294 | 6 / 1 | 2 | 90.72 |
| C | 14175 / 224 | 909 | 5 / 1 | 0 | 90.72 |

旋回は1tickごとに30度。回数は実行した行動数であり、異なる情報を得た回数ではない。Aは初期reserve30・携行食料0で、強制滞在中に約11まで低下した。食事を禁じたわけではないが、食料を持たない個体が外へ採食に出ることも止める設定の代償がある。今回途中で0にはならず、通常探索再開後に回復した。

## その後3日

| 個体 | 4日末reserve | 帰還完了 | 最終ノード / 辺 | 覚醒・睡眠候補 / 選択 |
| --- | ---: | ---: | ---: | ---: |
| A | 84.93 | 0 | 333 / 1106 | 0 / 0 |
| B | 83.85 | 0 | 309 / 855 | 0 / 0 |
| C | 83.65 | 0 | 219 / 448 | 0 / 0 |

睡眠レビュー計11回、158探索で仮説0。成功まとまり形成・H報酬付与も0。全日末で全員reserve>0。食料初期76＝消費15＋地上61、携行・倉庫0。

**観察フェーズは成立したが、拠点全体の関係構造を覚えたとはいえない。** 多数の旋回が4〜6キー・1辺にしかつながらず、既存の2特徴条件・視点統合・接続保持の問題を、観察時間の追加だけでは解決できなかった。開始位置周囲0.8mの局所観察なので、入口など拠点全域を十分に観察できた証拠でもない。ρ階層化や少数特徴の保持はこの試験では変更していない。

## 検証と再現

新規の設定観察・日境界検査9、既存MB33、実配置74（道19・岩壁33・生活22）、計116項目PASS。追加監査で初日入口通過0、全員のフェーズ完了、翌日以降の通常歩行、result/summaryの記録一致、地図整合・食料収支を確認。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/home_observation_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/home-observation-4d-20261025 --narrow-only --days 4 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on --home-observation on
node experiments/rock_gate/audit_home_observation.cjs outputs/home-observation-4d-20261025
```

証拠：[観察フェーズ監査](evidence/home-observation-four-day/observation-audit.json)、[日別集計](evidence/home-observation-four-day/summary.json)、[地図監査](evidence/home-observation-four-day/map-audit.json)、[manifest](evidence/home-observation-four-day/manifest.json)、[provenance](evidence/home-observation-four-day/provenance.json)。開始時の親コミットと、変更済み実行ソースのhashを区別する。実行後のintegrated.jlは末尾空行だけを整えた。
