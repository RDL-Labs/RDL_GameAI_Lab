# 獣道型選択経路の30日比較

2026-10-07、基準767dd59。[契約](../experiment-contracts/LW_selection_trail.md)。
seed20261005、軽量World A/B/C30日。比較元は保存済みbundle_credit30日。
新runは旧5秒creditをoff、期限なし親episode成功と使用定着をon。
複数変更の合成比較であり、一要因の効率改善試験ではない。

| 指標 | 前回 | 獣道型 |
|---|---:|---:|
| 採取 | 98 | 104 |
| 食事 | 96 | 99 |
| 最終reserve A/B/C | 74.95/82.01/81.07 | 88.93/86.30/90.25 |

道はA15/B1/C3件、実使用A20/B1/C3回。寄与11判断、選択変更2判断。
2件ともAの2日目でhome/step_-90からhome/step_-45へ変化し、最終commandはturn。
その時のreserveは95.31/94.14。成功creditは全員0なので使用定着による選択差。
食料不足中の適格使用episodeは今回0、未解決episodeも0。
したがって自然運転の「全体成功→強化→再使用」の成立例ではない。

合成試験では100秒後の親充足でも成功を返すこと、使用反復だけで選択が変わること、
同一道の反復が成功一票に留まること、再処理非加算、差替え操作非計数、本人binding、
保護phase非介入を確認。新規4件を含む関連38テストPASS。
全体suite/Luanti未実行。4608操作、食料保存・重複/時間重複なしの監査PASS。

効率改善・認知計算削減・習慣の一般性は未証明。後半の未達や固着も今後の観測対象。
[全edge/集計](LW_selection_trail.json)。生ログ outputs/selection_trail/enabled.jsonl。
再実行: `python -m integrations.lightweight.selection_trail_campaign`。
