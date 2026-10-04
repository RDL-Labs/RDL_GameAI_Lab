# 見える食料と身体障害 — 実行記録

2026-10-04。基準 d53dee7。軽量Python World、5条件を実行。
[契約](../experiment-contracts/LW_visible_food_obstacle.md)。Luanti実機は未実行。

| 条件 | 操作列 | 結果 |
| --- | --- | --- |
| 高さ.4、余力あり | walk(blocked) → climb → pickup | 実資源1取得 |
| 高さ.4、burst=0 | walk(blocked) → rest×2 → climb → pickup | 実資源1取得 |
| 高さ.7、視認可能・能力超過 | walk(blocked) → defer | 未取得 |
| 高さ2、食料を遮蔽 | defer | 未取得 |
| reserve=0、burst=0 | rest×8 | 回復なし、実験期限で終了 |

見えることは歩けることでも採取できることでもない。近距離の食料でも、
間に障害がある場合はpickupを拒否する別テストを通した。
成功2条件ともstock 1→0、inventory 0→1。残り3条件はstock 1のまま。
他個体不変、pickup再送で二重採取なし、身体操作IDとの競合拒否も確認。

実行:
```
python -m integrations.lightweight.visible_food_obstacle
python -m unittest tests.test_visible_food_obstacle tests.test_layered_body
```
専用5＋既存身体8＝13テストPASS。全体テスト未実行。
保存記録: `tests/fixtures/visible_food_obstacle.json`。再生成一致も検査。

これは固定された初期規則の身体利用で、学習成果・探索効率改善ではない。
既存探索への統合、迂回候補、観測不確実性、身体損傷、連続鉛直運動は次段階。
