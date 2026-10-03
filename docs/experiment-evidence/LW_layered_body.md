# 四層身体・軽量World試験

2026-10-04。基準280919f。[契約](../experiment-contracts/LW_layered_body.md)。

`python -m integrations.lightweight.body_fixture`。
22操作のscripted試験、既存軽量Worldの位置/方向/衝突幾何を利用。
Luanti実機、自律探索、Sleepへの学習投入ではない。

- run×3成立 → 4回目body_limited → walk成立。
- rest×5 → run再成立。
- 低障害へwalkはblocked → climbは成立。
- 回復後、高障害へclimbはblocked。
- fixtureで蓄え0・瞬発0・strain .8に変更。restで回復せずrunはbody_limited。
- fixtureで食料1単位をinventoryへ付与。eat → rest×2 → run成立。

枯渇状態・食料付与・障害配置/除去は実験者操作で、長期飢餓や採取を再現したものではない。
出典receiptに操作、前後の身体状態、変化量、移動距離、食料消費を保存。
`tests/fixtures/lightweight_layered_body.json`。

専用8テストPASS: 瞬発/持続の制限と回復、蓄えなしの回復抑制、食事と回復の分離、
損傷による能力制限、障害高と着地点、再送一回作用、個体分離、食品消費、状態検証。
既存探索本体へは未接続。全体テストは今回再実行していない。
