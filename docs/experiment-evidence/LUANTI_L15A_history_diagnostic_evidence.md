# L15A — 本人の短期履歴による移動診断

2026-09-28。基準 `main@c968d4e`。工程1のoffline診断を実施した。
Runtime・行動規則・係数・身体操作は変更していない。新規Luanti runは実施していない。

**steering v2で見つかった歩行復帰7窓は、すべて予定された周辺探索の往復だった。**
復帰だけを停滞反応へ接続すると、正常な探索を妨げる。このため目的による除外が必要である。
今回の限定条件では、保存済みv2の2runから新たな停滞反応の正例は得られなかった。
一般的な停滞が存在しないという結論ではない。

## 材料と方法

steering保存記録4run（v1/v2×草地/森林）とξ_tie保存記録5run、計9run・27個体run・3456観測。
`integrations/luanti/tests/diagnose_movement_history.py`で受理wireを順番に再生する。
各新規観測の直前に本人が受け取っていた最大8操作結果と、計最大9観測だけを取り出す。
未来の結果をsnapshotから遡って補わず、同じ観測の再送は新しい窓にしない。
全wire応答と最終Runtime snapshotは元記録と一致した。

履歴は2250000µs以内、同一period・連続取得枠。実行結果の出典・姿勢・revision・時刻を検査する。
unknown、未実行、取得不足は数値化しない。各実変位とyawを窓先頭の身体基準へ有限合成する。
最後にWorldの身体readbackと照合し、変位/角度の各誤差0.01未満を確認した。
この照合は診断後の監査で、World位置や全体地図を本人側の判定へ戻していない。

正味距離0.25以下、姿勢差5度以下、既存の粗視覚keyとFood外観/丸め距離が一致する場合に、
静止逆旋回と実経路長2以上の復帰を幾何的候補として表示する。
一致は同じ場所・対象の証明ではない。表示される窓は重なり、独立した経験数ではない。
採取、予定往復、目的の非継続、観測距離の改善を別に評価して、反復への加算可否を分けた。
この条件は既存記録を用いた探索的診断であり、独立した検証データによる精度評価ではない。

## 結果

| 記録 | 静止逆旋回の候補窓 | 歩行復帰の候補窓 | 目的条件も満たす反復候補窓 |
| --- | ---: | ---: | ---: |
| v1 草地（旧steering比較） | 81 | 6 | 70 |
| v2 草地 | 0 | 5 | 0 |
| v1 森林（旧steering比較） | 51 | 1 | 45 |
| v2 森林 | 0 | 2 | 0 |
| ξ_tie disabled 草地 | 134 | 0 | 110 |
| ξ_tie frozen 草地 | 134 | 0 | 110 |
| ξ_tie disabled 森林 | 51 | 1 | 45 |
| ξ_tie frozen 森林 | 51 | 1 | 45 |
| ξ_tie frozen 草地・故障注入 | 81 | 6 | 70 |

v2の7窓には、`neighborhood_survey`による「旋回→2歩→反転→2歩→向きを戻す」が残っていた。
これは追加観測のための往復で、同じ位置へ戻ったこと自体は失敗ではない。
正常往復を除外した後の正例0を隠さず、shadow機構がv2で有効になる証拠とはしない。

v1の静止反転は既にv2で抑制した問題であり、次の機構の改善実績に使い回さない。
静止した他の窓にはwaitや目的外の旋回も含まれる。採取なしだけで失敗には分類しない。
periodをまたぐ窓、時刻・実行結果の結合が成立しない窓もunknownのまま保存した。

## 保存と検証

全診断・候補出典・目的ゲート・独立World照合・入力hash・解析コードhashを
`tests/fixtures/luanti_l15a_history_diagnostic.json.gz`へ保存した。
元の実Luanti記録を変更せず、新しい診断結果として分離した。
222632 bytes、SHA-256 `649134a975584e7309c05b56c1b5099a427ade0e20d6ff2f54d03eacf5c0f373`。

専用10テスト: 静止反転、予定往復、同じ幾何で目的だけ異なる対照、実測方向変換、
同じ外観でも実移動あり、静止採取、欠測/遅延/姿勢不一致、目的変更/観測距離改善、
予算/重複/個体混線拒否、入力非破壊、9runのexact replayを検査する。
**10テストPASS**、8.344秒、exit code 0。
ログ: `integrations/luanti/output/l15a_history_tests.log`（Git管理外）。
全体テストと新規Luanti実機は今回再実行していない。

```powershell
python -m integrations.luanti.tests.diagnose_movement_history --output tests/fixtures/luanti_l15a_history_diagnostic.json.gz
python -m unittest discover -s tests -p test_movement_history_diagnostic.py -v
```

## 次工程への結論

[shadow契約](../experiment-contracts/LUANTI_L15A_repetition_shadow_contract.md)では、目的条件・非重複窓・
取得時刻による減衰を固定する。まず行動へ影響しない範囲で検証し、v2での認定0も対照として保つ。
実際の停止・再評価へ接続する前に、非意図的反復と正常な往復を分ける追加検証が必要である。
