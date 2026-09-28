# L15A — 反復残存・減衰3条件のshadow比較

2026-09-28、基準 `1879b2f`。有限offline実装と保存記録再生。
[契約](../experiment-contracts/LUANTI_L15A_repetition_shadow_contract.md)。
新規Luanti実行・全体テストは実施していない。Runtimeの行動規則・身体操作・学習・周期を変更していない。

## 訂正と実装

旧診断でv2の歩行復帰7窓を「予定された周辺探索なので除外」とした解釈を撤回した。
本人が反復を感じることを実験者の正常/異常評価で抑制しない。
今回、目的・成果による拒否と目的変更時の残存消去を使わず、同じ反復認定・閾値・寄与量で減衰だけを比較した。
旧目的付き成果物は履歴として保存。新成果物は別schema/ファイルである。

## 材料と結果

steering記録4runとtie-break記録5run、計9run・27個体run・3456観測。
受理wireから各時点の最大9観測と受信済み結果を再構成し、World監査前にshadowを計算。
元の全wire応答・最終Runtime snapshotと一致した。故障runの再送も新しい観測数にしない。
全profile共通で、操作の重ならない加算窓は**110件**。

| 減衰profile | 毎秒減衰 | 要求の出た個体run / 27 | false→true遷移 | 閾値以上の観測数 / 3456 |
| --- | ---: | ---: | ---: | ---: |
| fast | 1 | 0 | 0 | 0 |
| standard | 0.25 | 11 | 17 | 276 |
| persistent | 0.01 | 18 | 18 | 1190 |

閾値は全て2、寄与1、上限4。閾値以上の観測数は要求の持続を表し、1190回の独立要求や停止ではない。
同一軌跡を使うoffline比較なので、停止して軌跡が変わった後の予測ではない。
各個体runは独立した世界seedの標本とは限らず、9runは比較/故障条件を含む。統計的一般化はしない。

**v2の7つの予定往復は今回すべて加算された。** 個体ごとの加算は草地A/B/C=2/1/2、森林=0/2/0。
ただし、このv2記録では3profileとも閾値未到達。persistentでも2加算の最大残存は約1.98で、2未満だった。
閾値を下げて要求を作る追試はしていない。
上表の要求差は旧v1および独立tie-break経路の反復で生じており、v2の改善を示さない。

## 検証

専用11テストPASS（10.840秒）、旧履歴診断10テストPASS（8.471秒）、各exit code 0。
合成密反復はstandardで1→1.5→2、疎反復は1→1→1。
persistentでは疎反復でも閾値に到達し、同じ入力への減衰差を確認した。
予定往復、目的metadata非参照、成果保持、unknown、重複加算拒否、再送、競合、時刻逆転、容量、個体分離、上限を検査。
実記録全9runは成果物と完全一致を検査する。

成果物: `tests/fixtures/luanti_l15a_repetition_shadow.json.gz`。
入力archiveと実装のSHA-256を成果物内に保持し、全診断窓・profile別残存・要求・初回時刻を保存。

再実行:

```powershell
python -m integrations.luanti.tests.repetition_shadow --output tests/fixtures/luanti_l15a_repetition_shadow.json.gz
python -m unittest discover -s tests -p test_repetition_shadow.py
python -m unittest discover -s tests -p test_movement_history_diagnostic.py
```

## 次の境界

今回確認したのは、本人の同じ有限履歴でも反応の残り方で再評価要求が変わること。
実際に止まる・考え直す・有用な往復を中断する・脱出することは未実装。
次の閉ループ契約では要求の一回消費、停止/再開予算、既存優先権限を定め、利益と機会損失の双方を観測する。
