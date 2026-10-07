# 地面の局所パターン認識

2026-10-07、基準f27af1f。[契約](../experiment-contracts/LW_ground_pattern.md)。
seed20261005、軽量World A/B/C30日。保存済みground_appearance runと比較。

| 見た目 | 帯候補 | 面 | 形状材料不足 |
|---|---:|---:|---:|
| 草 | 486 | 4443 | 297 |
| 踏まれた草 | 1167 | 897 | 5086 |
| 露出地面 | 876 | 603 | 2888 |

判断時の延べグループ数であり、distinctな道・物体の数ではない。
草にも同じ規則を適用。茶色なら道というラベルをWorldから渡していない。
疎な15点の隣接と分散による候補であり、点間の連続性・川や道の意味は未確定。

全4608判断の保存patternが原観測からの再計算と一致。
全9216件のdecision command/completed command+resultが認識なしの記録と一致。
採取94・食事94、全員最終reserve正。既存食料保存/操作重複なし監査PASS。
関連24テストPASS。直線帯、遮蔽による分離、全面、全点未知、出典束縛、
入力出力独立、Runtime decision保存、再送、行動非介入を確認。
全体suite/Luanti未実行。

[延べ認識集計](LW_ground_pattern.json)。生ログ outputs/ground_pattern/enabled.jsonl。
実行 `python -m integrations.lightweight.ground_pattern_campaign`。
再監査 `python -m integrations.lightweight.audit_ground_pattern`。
