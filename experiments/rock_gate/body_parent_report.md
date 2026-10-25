# 身体要求による目的切り替え：最大30日試験

2026-10-25。Julia 1.13.1 / Windows。実行開始コミット5459e80。身体維持の**テスト用設定経路** `body_purpose=on` を有効にし、前回と同じ狭い入口・岩壁・分岐道・食料3地点・3個体で最大30日試験。seed=20261005。入力は前回の12日停止試験とbody_purpose以外が一致することを機械確認した。停止条件は「全員reserve 0かつ丸1日全員休息のみ」。死亡判定は使っていない。

## 結果

**30日上限まで正常完走。3体とも全日末reserve>0、終日休息の日なし。** 実行3366.63秒（約56分7秒、コンパイル込み）。全体は約3371秒以上（最終保存を含む）。日内の全tickでのreserve最小値は今回の集計では算出していない。

| 個体 | 前回：初めてreserve 0で終えた日 | 今回：30日末reserve | 今回：帰還完了カウンタ | 外出 / 入場 |
| --- | --- | ---: | ---: | --- |
| A | 10 | 92.33 | 6 | 5 / 4 |
| B | 11 | 89.30 | 2 | 4 / 3 |
| C | 11 | 68.94 | 3 | 4 / 3 |

帰還完了は目的状態のカウンタで、壁の通過回数と一対一ではない。今回は倉庫への搬入・取り出しとも0。採食してその場や携行中に消費することで身体維持につながった。備蓄行動の改善を示す結果ではない。

## 同じ12日目での比較

| 指標 | OFF（前回） | ON（今回） |
| --- | ---: | ---: |
| A reserve | 0 | 80.21 |
| B reserve | 0 | 76.90 |
| C reserve | 0 | 79.29 |
| 累計食料消費 | 23 | 42 |
| 地上食料 | 54 | 37 |
| 倉庫 | 1 | 0 |

試験期間の長さだけによる差ではなく、同じ12日間でも摂食量とエネルギー維持に差がある。基準側は12日末で全員停止条件が成立、ON側は30日目まで成立しなかった。

| 日末 | A reserve | B reserve | C reserve | 累計消費 |
| --- | ---: | ---: | ---: | ---: |
| 3 | 83.39 | 83.97 | 83.66 | 12 |
| 6 | 96.28 | 74.77 | 75.55 | 22 |
| 12 | 80.21 | 76.90 | 79.29 | 42 |
| 18 | 87.94 | 80.46 | 85.93 | 63 |
| 24 | 92.21 | 65.28 | 87.33 | 83 |
| 30 | 92.33 | 89.30 | 68.94 | 104 |

## 設定経路の使用・H・食料収支

帰還要求がある中で身体要求からfoodを選んだ判断数はA143680 / B236595 / C138746。目的選択の切り替え回数はA70 / B54 / C67。各個体の判断は518400回。安全行動等の最終上書き前の統計なので、食料探索の実行回数とは異なる。日別の差分も保存した。

目印候補生成の段階0/1/2はA52/52/397306、B38/38/437522、C36/36/411490。約99.98%が段階2であり、低Hで候補を絞る学習効率化は依然確認できない。身体維持の成功と、目印・経路選択のHが下がることは別の課題。

最終地上は左10 / 中央22 / 右11＝43。初期76＋再生72＝消費104＋地上43＋携行1。倉庫・個人倉庫0。採取総量は72＋72−43＝101。食料再生の規則は同じだが、消費した分だけ補充が生じるため、再生総量は前回より増えている。

この1seed・1配置では身体維持に大きな改善が見られた。ただし変更は空腹時の目的切り替えだけでなく、その設定経路に含まれる夜間休息・社会応答待ちの解除、即時摂食の優先も含む。どの要素が寄与したかは分離していない。**埋め込みMBや自律的に学習した上位選択の成功とは扱わない。** 設定経路を撤去して同じ身体維持が成立することは未検証。

## 検証・再現

道構造19、岩壁33、30日生活保存則152、計204項目PASS。追加集計で入力同一性、日数・終了時刻、全日食料保存・行動数・有限reserve、上位状態のsummary一致、判断数と記録上限を確認。

```powershell
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/body-parent-30d-20261025 --narrow-only --days 30 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --stop-exhausted
node experiments/rock_gate/summarize_food_days.cjs outputs/body-parent-30d-20261025 outputs/body-parent-30d-20261025/daily-summary.json
node experiments/rock_gate/compare_body_parent.cjs outputs/body-parent-30d-20261025 outputs/food-roads-lazy-cues-30d-20261025 outputs/body-parent-30d-20261025/body-comparison.json
```

証拠：[日別集計](evidence/body-parent-thirty-day/summary.json)、[同期間比較・上位判断](evidence/body-parent-thirty-day/body-comparison.json)、[停止理由](evidence/body-parent-thirty-day/termination.json)、[個体別結果](evidence/body-parent-thirty-day/report.json)、[manifest](evidence/body-parent-thirty-day/manifest.json)。manifestのday.jlは通過観測・早期停止の実験フックを含む。
