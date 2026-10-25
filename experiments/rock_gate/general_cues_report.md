# Hによる目印候補の拡張：3日試験

2026-10-25。Julia 1.13.1 / Windows。同じ狭い入口・分岐道・食料3地点・3個体、seed=20261005。前回3日試験の入力と `general_landmarks=on` 以外が一致することを機械照合した。[実装範囲](../../docs/design/LW_Observed_Cues.md)。

## 結果

3日を正常完走。実行238.90秒（コンパイル込み）、全体約244秒。前回225.02秒との差は約6.2%だが、単発・行動内容も異なるため純粋な処理オーバーヘッドの測定ではない。

| 個体 | 前回の帰還完了 | 今回の帰還完了 | 今回の外出/入場 | 3日末reserve | 3日末 |
| --- | ---: | ---: | --- | ---: | --- |
| A | 1 | 0 | 1 / 0 | 83.21 | 帰還未解決 |
| B | 0 | 1 | 1 / 1 | 82.99 | 拠点、帰還完了 |
| C | 0 | 1 | 2 / 1 | 85.46 | 再外出後、帰還未解決 |

Cは1日目に帰還して食料2個を搬入。Bは3日目に帰還。前回は搬入0。今回は左3 / 中央0 / 右8を採取、計11で前回と同量。消費も12で同じ。最終地上61、倉庫2、携行1で、初期76＝消費12＋地上61＋倉庫2＋携行1を保存する。エネルギー枯渇・クラッシュはなかった。

## 候補の使用とコスト

| 個体 | 段階0選択 | 段階1選択 | 段階2選択 | 前回scan | 今回scan |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 2160 | 10288 | 4740 | 2430 | 11445 |
| B | 2118 | 10670 | 4795 | 2416 | 12066 |
| C | 1907 | 7581 | 3411 | 2521 | 9141 |

各個体51840行動中、scanは前回4.7–4.9%から今回17.6–23.3%へ増加。曖昧な候補と相対配置も実際に選択された。色・上方輪郭・光・地面・食料・動く対象・配置の全カテゴリで選択あり。候補上限による切り捨て0。ochreの観測候補はA6419/B6586/C5290回。ただし色の観測であり、塔の同定や帰還への因果的寄与を示す値ではない。

帰還と搬入に改善の兆しはあるが、Aは未帰還、Cも2度目の帰還が未解決。候補追加による観察増加や確率系列の変化も含む1seedの比較であり、安定した往復や特定の目印の効果を証明しない。今回は結果を見てパラメータ調整せず記録した。

## 検証と再現

追加ユニット28、既存の近距離目印10・光源13・確率選択116、試験内の道構造19・岩壁33・生活保存則17、計236項目PASS。加えてNode集計で入力一致・食料保存・日別行動数・有限reserve・選択段階と不確実性の整合を確認。

```powershell
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/food-roads-general-cues-3d-20261025 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on
node experiments/rock_gate/summarize_food_days.cjs outputs/food-roads-general-cues-3d-20261025 outputs/food-roads-general-cues-3d-20261025/daily-summary.json
node experiments/rock_gate/compare_general_cues.cjs outputs/food-roads-general-cues-3d-20261025 outputs/food-roads-on-3d-20261025 outputs/food-roads-general-cues-3d-20261025/cue-comparison.json
```

証拠: [日別集計](evidence/general-cues-three-day/summary.json)、[候補と比較](evidence/general-cues-three-day/cue-comparison.json)、[個体別結果](evidence/general-cues-three-day/report.json)、[通過イベント](evidence/general-cues-three-day/crossings.jsonl)、[ソースhash](evidence/general-cues-three-day/manifest.json)。provenanceのcommitは実行開始時の親コミットで、変更済みソースはmanifestのhashと本コミットで対応づける。day.jlの実行コピーには読み取り専用の通過記録フックを挿入している。
