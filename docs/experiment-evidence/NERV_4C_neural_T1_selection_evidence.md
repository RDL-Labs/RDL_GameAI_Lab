# NERV-4C 有限神経relation選別 Evidence

状態: **PASS / N4C-01〜10完了 / T1-B記録まで固定** / 2026-09-27。
実装開始点: `990881a`。[契約](../experiment-contracts/NERV_4C_neural_T1_selection_contract.md)に対応。

## 今回の機能

`runtime/neural_selection.py`に純粋な`evaluate_neural_t1_selection`と、
明示記録の`record_neural_t1_selection`を追加した。
NERV-3材料→NERV-4A/4Bを再実行し、渡された凍結bundleを一時storeで再構築して内容照合する。
検査用の材料を追加しても、形成用3経験のCandidateや支持数を再形成・増加させない。
同じExperience、同じeventを形成用と検査用の両方へ使うと拒否する。

検査目的は`inspect_food_acquisition_recurrence`、規則は`nerv-food-acquisition-selection-v1`。
初版はacquisitionだけを比較する。モデルにFood取得次元がなく、または対応記述がなければDEFER。
意味を持つ次元の対応があり、全検査経験が同contextで比較可能な場合に限り、全件一致でRETAIN、
一件以上不一致でREJECT。成功取得だけを評価する規則ではなく、負の取得結果の再現も同じ規則でRETAINになる。

## 検証結果

| 条件 | 結果 |
| --- | --- |
| 正の取得3形成経験＋正の取得3検査経験 | acquisition RETAIN、形成支持3/検査3 |
| 負の取得3形成経験＋負の取得3検査経験 | acquisition RETAIN |
| 正→負、負→正の未使用検査経験 | acquisition REJECT |
| 個数観測モデル・対応記述なし・検査経験なし | DEFER、理由を保持 |
| 反例1件＋別contextの検査経験 | 全体DEFER、比較可能な反例もpair_resultsへ保持 |
| 他の3relation | DEFER / relation_out_of_scope |
| canonical4材料 | 全件DEFER / canonical_material_out_of_scope |
| 神経で除外されたrelation | 子材料へ復活せず、親診断で追跡 |

標準ケースはT1-B記録8件でRETAIN=1、DEFER=7、REJECT=0。
全材料にbasisと構造化診断の確定JSONをevidenceとして残す。
形成支持数と検査件数を分け、raw/neuralを二つの独立票として加算しない。

## 合成fixtureと信頼境界

RETAIN/REJECTのモデルは、既存モデルのコピーに`food_acquisition_outcome`と係数を追加した明示合成入力。
Food作用断面からcanonical F/Eを実際に形成したモデルの証拠ではない。
同じ名前の次元があれば現実の意味適合性が保証されるという主張もしない。
固定されたadapterの意味・符号・不一致許容数0を検査し、実モデルへ接続する取得・解釈契約は保留する。

形成・検査用Outcomeは既存Python fixtureをNERV-3で受理した記録である。
正負のFood成立値は試験側で指定した条件で、実Luantiの成否分布ではない。
現行acquisitionは常に強度3で、神経条件による抑制が生じない。
合成raw zeroを与えたケースでは、neural再計算が整合していてもboolean取得規則と矛盾するため入力拒否した。
比較不能と反例の併存はcontext差で検証した。

同eventを別Experienceに見せる拒否試験には、神経projection/Biasを再計算した合成材料を使った。
容量試験では既存汎用ledgerに別bundle IDの明示fixtureを先に登録した。
両者とも実運転でその状態が自然発生した証拠ではない。

呼出し側が現行snapshotを渡す責務はNERV-4Bと同じ。完全に整合した古い/偽造snapshotの外部認証は行わない。
入力順・検査ID順・bundle材料順を変えても評価結果とIDは一致し、返却内容を変更しても入力と保存stateは不変。

## 明示記録・権限

T1-Bへの記録時も再評価する。既存ledgerのexpected_revisionを維持し、同revisionの再送は拒否。
次revisionの明示再検査ではrevisionのみ進み、評価内容と形成支持数は同じ。
容量拒否は既存記録を保持する。reviewer不正・改変・参照不正は部分記録を残さない。
ledgerは最新版保持で、全revisionの永続履歴ではない。

純粋評価で全store不変、明示記録でT1-Bだけ変化することを確認した。
NERV保存state、T1-A、canonicalモデル、再構成・cutoverは一致。
再構成関数を呼ぶと失敗する試験用置換を置いても受付は完了した。
固定3packetのAction/InteractionHistoryも記録あり・なしで一致。実World行動差の検査ではない。
汎用T1-Cを別途明示呼出しすること自体を禁止するセキュリティ機構は追加していない。

## 受入と全体回帰

`tests/test_neural_selection.py`: **15テストPASS**。

| 受入 | 対応する検査 |
| --- | --- |
| N4C-01/02/03 | 対応不足、正負の再現・反例、反例とcontext差、複数理由 |
| N4C-04 | 支持/検査件数の分離、raw/neural対、filtered関係の非復活 |
| N4C-05 | Experience/event重複、未知・改変・model/target不一致、取得規則不整合 |
| N4C-06 | 6検査経験、7指定/32 Bias超過拒否、順序・alias |
| N4C-07 | 全8材料のdisposition、basisとJSON evidenceの一致 |
| N4C-08 | revision再送拒否、明示再検査、容量・不正reviewで部分更新なし |
| N4C-09/10 | 評価の非介入、記録はT1-Bのみ、再構成非呼出し、Action/履歴と全体回帰 |

```text
python -m unittest discover -s tests -v
Ran 483 tests
OK (skipped=46)
483件実行 = 437 PASS + 46 intentional skip
```

既存Sleepなどの経路は全体回帰で検査。既存runtimeの変更なし。
Luanti/HTTP/ブラウザーは今回再実行していない。
T1-C・M_B更新・Goal/Trajectory・神経差による行動差は未接続である。
