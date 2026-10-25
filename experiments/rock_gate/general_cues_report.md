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

## Hで生成を省略して再試験（2026-10-25）

低Hでは追加候補の生成処理を省略する変更を加え、同じ初期状態から再び3日実行した（前回末尾からの継続ではない）。出力 `outputs/food-roads-lazy-cues-3d-20261025`。上記コマンドの出力先だけ変更して再現可能。

3日正常完走。日別状態・日開始状態・イベントは前回3日と完全一致。B/C各1回帰還、Cが2個搬入、A未帰還、Cの再帰還未解決。候補上限による切り捨て0。追加チェック34＋実行時チェック69、計103項目PASS。

| 個体 | 段階0生成回数 | 段階1生成回数 | 段階2生成回数 |
| --- | ---: | ---: | ---: |
| A | 4 | 4 | 34176 |
| B | 4 | 4 | 34003 |
| C | 8 | 8 | 24099 |

候補生成呼び出し92310回中92278回（99.97%）が段階2で、低Hの省略機会は32回のみ。実行255.58秒（コンパイル込み、全体約260秒）、前回238.90秒に対して約7%長く、速度改善は確認できなかった。単発測定なので変更が遅延の原因とも断定しない。今回の未解決状態では高Hが続くため、遅延生成の利点は小さい。学習によって少数候補で目的を解決できる状態を作れるかが別の課題。

候補生成以外の知覚・安全処理は省略しない。思考に対する身体エネルギー消費も追加していない。候補全生成時との一致を確認した範囲は今回の観測と単体チェックであり、候補上限に達する任意の観測での同値性は保証しない。

[日別集計](evidence/lazy-cues-three-day/summary.json)、[3日一致監査](evidence/lazy-cues-three-day/prefix-audit.json)、[生成統計](evidence/lazy-cues-three-day/cues.json)、[manifest](evidence/lazy-cues-three-day/manifest.json)。実行コピー作成後、コミット側はBOMと末尾空行のみ正規化したためソースhashに差がある。実行day.jlには従来同様の通過記録フックがある。

## 最大30日・全員継続不能で停止（2026-10-25）

同じ初期状態・seedから再実行し、**12日末に自動終了**。死亡フラグはないため、停止条件は「日末に全員reserve 0、かつその1日全員の行動が休息のみ」とした。30日上限。途中でプロセスを強制終了せず、日末集計と最終状態を書き出して正常終了する。判断・身体消費のルールは変更していない。停止処理は実験コピーへのフックで、通常のLW実行には影響しない。

最初の3日の日別状態・日開始状態・イベントは直前の3日試験と完全一致。実行1256.46秒（約20分56秒、コンパイル込み）、全体約1261秒。途中の実時間変動があり、速度の厳密な比較には使用しない。

| 個体 | 初めてreserve 0で終えた日 | 終日休息開始 | 帰還完了 | 外出/入場 |
| --- | ---: | ---: | ---: | --- |
| A | 10 | 11 | 0 | 1 / 0 |
| B | 11 | 12 | 1 | 3 / 2 |
| C | 11 | 12 | 2 | 3 / 2 |

Cは1日目に食料2個搬入、5日目に再帰還して倉庫から1個を取り出した。その後は全員が補給・往復を維持できずにエネルギー切れとなった。入口の往復通過と目的の帰還完了は別カウンタ。

最終地上食料は左18 / 中央24 / 右12＝54、倉庫1、携行0。初期76＋再生2＝消費23＋地上54＋倉庫1を保存。採取総量20。世界の食料枯渇ではない。

| 個体 | 段階0生成回数 | 段階1生成回数 | 段階2生成回数 |
| --- | ---: | ---: | ---: |
| A | 4 | 4 | 121529 |
| B | 8 | 8 | 132584 |
| C | 12 | 12 | 118421 |

候補生成372582回のうち低い段階は48回のみ。段階2が**99.987%**で、長期化しても低Hで省略する機会は増えていない。これは目印候補を生成する判断場面での統計であり、全生活時間のH分布ではない。後半の計算時間短縮を学習効率化とは解釈しない。全員が行動停止へ向かったためである。

目印拡張前の30日試験では全員reserve 0が18日末だったのに対し、今回11日末。3日だけで見えた帰還・搬入の改善は、今回のseedで長期の維持には結びつかなかった。ただし候補拡張・色観測・選択系列の違いを含む比較で、原因を単一要素には帰属できない。今後の診断対象は、目的未解決のHが上限近くで続く理由と、補給へ切り替えられない区間。

停止判定5項目、道構造19、岩壁33、12日生活保存則62、計119項目PASS。集計時にも停止理由・実行日数・最終日の全員休息・reserve 0・食料保存を検査した。

```powershell
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/food-roads-lazy-cues-30d-20261025 --narrow-only --days 30 --rho coarse --rho-openings on --food-roads on --general-landmarks on --stop-exhausted
node experiments/rock_gate/summarize_food_days.cjs outputs/food-roads-lazy-cues-30d-20261025 outputs/food-roads-lazy-cues-30d-20261025/daily-summary.json
node experiments/rock_gate/compare_prefix.cjs outputs/food-roads-lazy-cues-30d-20261025 outputs/food-roads-lazy-cues-3d-20261025
```

[日別集計](evidence/lazy-cues-until-exhausted/summary.json)、[停止理由](evidence/lazy-cues-until-exhausted/termination.json)、[3日一致](evidence/lazy-cues-until-exhausted/prefix-audit.json)、[候補統計](evidence/lazy-cues-until-exhausted/cues.json)、[manifest](evidence/lazy-cues-until-exhausted/manifest.json)。config.days=30は上限、実行日数はtermination.completed_days=12、ended_usは12日分。manifestのday.jlには観測フックと日末停止フックを含む。
