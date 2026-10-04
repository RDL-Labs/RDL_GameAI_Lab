# 探索と身体の接続 — 4条件比較

2026-10-04。軽量Python Worldで実行。[契約](../experiment-contracts/LW_body_exploration.md)。

| 条件 | 主な操作 | 採取 |
| --- | --- | --- |
| crossing無効 | acquisition_incompleteで待機 | 0 |
| crossing有効 | climb → pickup | 1 |
| 有効・burst=0 | wait×2 → climb → pickup | 1 |
| 有効・高さ.7（能力.6） | acquisition_incompleteで待機 | 0 |

同じHarvestCampaign系の観測→判断→World操作→result受付を通した。
成功条件では取得後の次観測も実行。結果は全件Runtimeが受理し、実資源stockを減らして
inventoryへ移した。後続観測を含めてもlearning_recordsは0。
地面の部分取得が残り、既存の学習適格条件を満たさないため、学習成功とは呼ばない。

専用8テストでは、障害のない場面の.5歩行、誤った1単位結果の拒否、
観測・操作再送、個体分離、古い姿勢、期限切れ、観測binding、
取得後に着地点を塞いだ場合のWorld拒否、保存再生一致を確認。
既存身体・視認障害・探索・採取・帰還campaign・steeringを含む計72テストPASS。
全体suiteおよびLuanti実機は未実行。

保存記録: `tests/fixtures/body_exploration.json`。
再実行: `python -m integrations.lightweight.body_exploration`。
今回の差は初期身体能力への接続によるもの。迂回改善やSleep学習の効果ではない。
