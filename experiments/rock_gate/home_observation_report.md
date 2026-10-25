# 初日見回し＋通常探索3日

## 追試：初日備蓄あり・計10日（2026-10-25）

c0298a5の実装、同じseed・地形。初日見回し＋9日通常判断に、各開始位置4食ずつ（計12食）の有限備蓄を追加。通常pickup/eatで消費し、自然再生しない。754.22秒（約12分34秒、コンパイル込み）で10日正常完走。ピークRSS約1.53GB。実配置104項目PASS、観察・地図・食料の自動監査すべてexit=0。

初日入口通過0、全員の観察フェーズ完了を確認。Aは初日4回取得・4回摂食し、reserve30→90.74。前回の備蓄なし11.08から低下を回避。B/Cも初日末90.72。初日末の地図は依然A4/B6/C5ノード、各1辺。

| 個体 | 最終reserve | 外出 / 外からの再入場 | 帰還目的完了カウンタ | 睡眠仮説発見 / 覚醒時提示 / 選択 |
| --- | ---: | ---: | ---: | ---: |
| A | 90.84 | 1 / 0 | 2 | 0 / 0 / 0 |
| B | 73.97 | 3 / 2 | 4 | 0 / 0 / 0 |
| C | 94.57 | 3 / 2 | 4 | 1 / 0 / 0 |

**Cで初日の睡眠に仮説が1件生成されたが、実利用は0。** 2日目レビュー時点でも保持1件、3日目には0件。経路そのものと候補化を阻んだ条件の履歴は保存されていないため、帰還経路だったとは断定せず、未使用の直接原因も未特定とする。覚醒の詳細探索候補、成功まとまり形成、まとまりへのH報酬はいずれも全員0。

最初の外出は全員3日目（C34749秒、A34890秒、B35488秒）。2日目から強制観察は解除されたが、通常判断で拠点内に留まった。2日目に全員の帰還目的カウンタが2になっており、拠点内での目的完了を含む。カウンタ2/4/4を外出からの帰還回数と混同しない。

全日末で全員reserve>0。初期88＋再生5＝消費35＋地上51＋共有倉庫7、携行0。備蓄3地点は終端すべて0。倉庫搬入12・取り出し5。備蓄の追加で食料の可視性・行動・資源状態も変わるため、帰還や仮説生成を見回し学習だけの効果とは判定しない。

再現は下記コマンドの出力先をhome-provisions-10d-20261025、daysを10にし、--stop-exhausted --camp-provisions 4を追加する。

証拠：[初日監査](evidence/home-provisions-ten-day/observation-audit.json)、[日別集計](evidence/home-provisions-ten-day/summary.json)、[地図・睡眠](evidence/home-provisions-ten-day/map-audit.json)、[manifest](evidence/home-provisions-ten-day/manifest.json)、[provenance](evidence/home-provisions-ten-day/provenance.json)。

## 最初の備蓄なし4日試験

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
