# NERV-4B 神経由来T1検査材料 Evidence

状態: **PASS / N4B-01〜10完了 / UNINSPECTEDまで固定** / 2026-09-26。
実装開始点: `b5a27b8`。[契約](../experiment-contracts/NERV_4B_neural_T1_boundary_contract.md)に対応。

## 実装した入口

`runtime/neural_t1.py`に以下を追加した。

- `prepare_neural_t1_materials(materials, candidate_request)`: NERV-4Aと前段compilerを再実行し、共通relationごとの材料を作る純粋関数。
- `expand_neural_t1_materials(...)`: 同じ再検証を内部実行し、明示bindingとcanonical参照を検査して、渡されたT1-A storeへ展開する。

準備schemaは`nerv-t1-preparation-v1`、子材料schemaは`nerv-t1-relation-material-v1`。
候補辞書やprepared出力を直接信頼する入口はない。未知・改変・欠落・個体混線は前段で拒否する。
子材料は最大4件。各Experienceのraw dimensionとneural dimensionを一組で保存し、支持数を二倍にしない。
神経parameter・元Candidate/result・関係別Bias/Experience・各projection/raw/eventを追跡できる。
親の全診断を子payloadに含めるため、凍結bundleにも除外関係の理由が残る。

## 有限再生の結果

NORMAL reward・light injuryを3経験繰り返した既存Python fixtureでは、
(sensitivity, threshold)=(1,1)/(1,3)/(3,1)/(3,3)で子材料がそれぞれ2/2/4/3件となった。
各関係の支持は3 Experienceで、raw/neuralを独立な証拠として加算していない。
3件HIGH＋4件目NORMALの抑制ケースでは、reward_valueの子材料を作らず、3件の支持と4件目の抑制を親診断に残した。

経験不足・文脈差・全zero・全抑制では`no_inspection_materials`と元診断を返し、T1-A storeを変更しない。
全zero/全抑制は既存のraw dimensions置換を使う合成fixture。実Worldの経験分布の主張ではない。
最大6経験で4子材料、前段の7経験指定・32 Bias超過は明示拒否。順序を入れ替えても準備結果全体が一致する。
返却内容の変更は元材料・保存bundleへ波及しない。

## T1-A受付と権限

既存の`reviewed_sidecar`で有限なE評価・明示reviewからactive M_deltaを作り、そのsnapshotを使用した。
正常受付ではcanonical材料4件＋神経由来relation材料4件が展開され、**全8件がUNINSPECTED**。
神経関係はGameAI-localな検査材料であり、T1-AのCandidateRelationというkindに置かれても採用済み構造ではない。

- purpose・run/agent・transition/model/assessment・boundary/criteria参照を検査する。
- inactive、canonical参照不一致、別個体、binding不一致を拒否する。
- 同入力の再送は同bundle。cycle・boundary・criteria変更は既存の凍結入力競合として拒否。
- 旧Local Bias経路が使ったtransitionへ追記・上書きしない。
- 容量1のstoreで1件受付後、別transitionは`capacity_rejected`。既存bundleは保持し、拒否counterだけ増える。満杯時の同入力再送は成功。

異なるtransition IDによる容量試験は明示的な合成条件であり、実運転の複数遷移を再現したものではない。
canonical snapshotは呼出し側が現在のものを渡す契約である。本関数はその内部参照整合性を検査するが、
全部まとめて古いsnapshotや偽造snapshotを外部情報で認証する仕組みではない。
run bindingはcallerの明示出典であり、canonicalに存在しないrun情報を生成しない。
boundary_ref/criteria_refも意味的適合性や選別成功の証拠ではない。

## 検証と停止境界

`tests/test_neural_t1.py`: **12テストPASS**。

| 受入 | 検証 |
| --- | --- |
| N4B-01/02 | 四隅の材料数、3支持、raw/neuralの対応・依存性 |
| N4B-03 | 4件目抑制、候補なしの全状態、子材料の復活なし |
| N4B-04 | 未選択の改変・欠落・旧schema・混線、偽Candidate拒否 |
| N4B-05 | 上限、順序不変、入出力独立 |
| N4B-06 | binding・inactive・canonical参照不一致拒否 |
| N4B-07 | 再送・変更・旧bundle競合・容量と部分更新なし |
| N4B-08/09 | 全材料UNINSPECTED、親診断とbindingを凍結保持 |
| N4B-10 | 準備でstate不変、受付でT1-Aのみ変化、固定packetのAction/履歴不変、全体回帰 |

明示受付前後でNeuralOutcomeCoordinatorの保存state、canonicalモデル・選別・再構成・cutoverは一致した。
固定3packetで受付あり／なしのActionとInteractionHistoryも一致する。既存Sleep/T1経路は全体回帰で検査した。
NPCが神経差に応じて行動を変えたという検証ではない。

実行: `python -m unittest discover -s tests -v`

```text
Ran 468 tests
OK (skipped=46)
468件実行 = 422 PASS + 46 intentional skip
```

既存runtimeファイルの変更はなく、独立モジュール・試験・文書の追加/更新である。
Luanti・HTTP・ブラウザーは再実行していない。process内の逐次呼出しを対象とし、並行受付・永続化は未検証。
NERV-4BからT1-BのレビューやT1-C/cutoverを自動起動しない。
次段で選別する際には、問い・適用域・許容損失・反例条件・モデルとの対応を別契約で定める。
