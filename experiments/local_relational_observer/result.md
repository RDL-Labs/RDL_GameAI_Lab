# 局所H・ρ・境界試験

人工MB、既存BasicLoop/relational_transition使用。本体・長期実験への接続なし。

| 条件 | 候補 | 選択確率 |
|---|---|---|
| 粗いρ / H=0 | familiar_route, alternative_route | 0.952574, 0.047426 |
| 粗いρ / H=8 | familiar_route, alternative_route | 0.645656, 0.354344 |
| 細かいρ / H=8 | familiar_route, alternative_route | 0.41096, 0.58904 |
| 境界1件 / H=8 | familiar_route | 1.0 |
| 境界2件 / H=8 | familiar_route, alternative_route | 0.645656, 0.354344 |

確認候補順: refine / coarsen / widen

細部確認が有望: [0.446469, 0.260179, 0.293351]

全体把握が有望: [0.254045, 0.453734, 0.292221]

確率分布の比較であり、行動の連続実行・見込みの学習・実際の帰還改善は未検証。
