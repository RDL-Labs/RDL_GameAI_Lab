# 重量・障害・荷物を置く — 有限比較

2026-10-04。基準35ad832。[契約](../experiment-contracts/LW_cargo_obstacle.md)。

軽量Worldの高さ.4・半径.1の障害で比較。各ケースは実資源を拾うところから記録。

| 条件 | 選択・実行 |
| --- | --- |
| 5個 | climb成功（能力.4） |
| 6個 | drop1 → climb成功（能力.375→.4） |
| 6個・burst=0 | drop1 → rest3回 → climb成功 |
| 6個・側方候補あり・帰還目的 | detourの実1歩、6個保持 |
| 同じ観測・逃走目的 | drop1 → climb成功、5個保持 |

5/6個の境界は高さと連続的な荷重式の結果。個数6を禁止する規則ではない。
別のWorld実行テストでは、6個のままclimbするとblocked、休んで再試行してもblocked、
1個置くと成功することを確認した。置いた物の他個体による取得、再取得後の再制約、
drop再送での二重生成防止も確認。重量合計は常に初期資源量と一致。

移動消耗は重量0/1/5/6で単調増加。疲労と負傷は別条件として残る。
専用7＋既存身体/探索接続/Sleep統合など計33テストPASS。
全体suite・Luanti実機・長期探索へのcargo接続は今回未実施。

再実行: `python -m integrations.lightweight.cargo_obstacle`
記録: `tests/fixtures/cargo_obstacle.json`。
逃走中の荷物軽減の候補選択までで、動く脅威から逃げ切った証拠ではない。
