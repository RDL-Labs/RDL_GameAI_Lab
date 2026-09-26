# NERV-4C 神経由来relationの有限検査・選別契約

状態: **DESIGN ONLY / 未実装・受入未実施** / 2026-09-27。
基準: `f9849fe4`。[前段Evidence](../experiment-evidence/NERV_4B_neural_T1_boundary_evidence.md)。

## 1. 用途と停止点

初版の問いは「指定したFood contextで、形成用経験に共通した取得結果relationが、形成に使わなかった検査経験でも再現するか」。
目的名は`inspect_food_acquisition_recurrence`、規則版は`nerv-food-acquisition-selection-v1`。
検査するrelationは`acquisition`だけ。他のneural relationは消さずDEFERする。
選別記録まで実装対象とし、T1-C再構成・M_B更新・Goal/Trajectory・行動差は追加しない。
成功取得を優遇する規則ではない。負方向のCandidateでも、指定した負の取得結果が検査経験で再現すれば同じ条件でRETAIN可能。

## 2. RDLとの関係

Core参照は`327098256a29e3f82f2a8649a6ec0202fd68a6c4`のT1_検査と選別、T1_SILN展開、T0 SPEC。
[Lab意味参照](../semantic-reference/RDL_Core_T0_T1_reference.md)に従い、目的・境界・許容損失を先に固定する。
raw/neuralは同じ経験由来で二票ではない。知覚relationも検査差もcanonical F/E/Hへ自動変換しない。
RETAINはこの有限検査の適合、REJECTは同条件での不適合、DEFERは判定条件不足。
どれも世界の真理、対象の普遍的価値、安全性や行動指令ではない。

## 3. モデル側の対応を明示する

初版の対応記述schemaは`nerv-food-acquisition-target-v1`。
model_ref、boundary_ref、criteria_ref、target_dimension、relation=`acquisition`、context_signature、
符号の意味（取得成立=positive、取得不成立=negative）、許容不一致数=0を持つ。
全記述を検査結果へ凍結し、単なる参照文字列の存在を適合の証明にしない。

対応を許可するのは、指定modelのboundaryに`food_acquisition_outcome`という次元が宣言され、
対応記述のtarget_dimensionもこれと一致する有限fixtureだけ。
その次元の意味は、既存Outcomeのfood取得成立/不成立を同じ符号に写す、この規則版で固定した明示adapterとする。
位置・時刻・ID文字列や`visible_objects_count`等の個数からFood取得結果を推定しない。
モデルとbindingの参照が食い違う入力は拒否。参照は整合するが対応次元/対応記述が存在しなければDEFER。

現行の個数観測canonical fixtureにはこの次元がないためDEFERを期待する。
RETAIN/REJECTの正例には、この意味を明示した専用Pythonモデルfixtureを別途作る。
これは実NPCのM_BへFood意味が実装済みという証拠ではない。実モデルへの接続には別の取得・解釈契約が必要。

## 4. 形成用と検査用の経験を分離する

入力案は、凍結済みNERV-4B bundle、NERV-3材料、元candidate_request、
明示した検査Experience ID、対象モデル、対応記述、reviewer/expected_revision。
NERV-4Bの準備を再実行し、bundle内の親結果・子材料・bindingと照合する。
任意のCandidateや「検査済み」と書いた辞書を信用しない。
材料全体を既存compilerで再検査し、未選択の改変も拒否する。

検査Experience IDは0〜6件、重複は拒否、上限は重複排除前に検査。
形成用3〜6件とのExperience IDと元event IDの重複を拒否する。
同run/agent/固定parameter全内容、同context、同じraw/neural規則を要求する。
同一経験の別表現、同event再送、Sleep cycle変更を独立な再検査証拠にしない。
検査経験の時刻が後であることはIDから推定しない。「未使用の経験」の有限検査であり未来予測の検証とは呼ばない。

前段の材料上限128 projection/32 Biasを維持。形成用と検査用を合わせて上限を超えれば明示拒否。
最大6検査経験を必ず使い切れるという保証ではない。自動選択・履歴総当たり・切り詰めはしない。
子材料最大4件、検査判定は最大4×6件。初版の実際の再現比較はacquisitionだけで最大6件。

## 5. 判定規則

まず全検査経験を確認し、各経験のraw dimensionとneural dimensionを一組で残す。
検査用の取得成立/不成立を既存outcome_factsから再導出し、保存raw dimensionと整合することを確認する。
改変・欠落・規則不整合は入力拒否とし、REJECTへ混ぜない。
raw/neural対応を検査するためにWorldへ問い合わせない。

| 条件 | disposition / 理由 |
| --- | --- |
| relationがacquisition以外 | DEFER / relation_out_of_scope |
| モデル側の対応記述/次元がない | DEFER / target_mapping_unavailable |
| 検査経験が0件 | DEFER / no_validation_experience |
| 参照は正当だが検査経験のcontextが異なる | DEFER / validation_context_mismatch |
| raw zero・neural_filtered等で非zero比較が成立しない | DEFER / validation_not_comparable |
| 全検査経験が同じ対応条件で比較可能、Candidateの方向・強度と全件一致 | RETAIN / recurrence_within_declared_scope |
| 全検査経験が比較可能で、少なくとも1件で方向または強度が不一致 | REJECT / recurrence_counterexample |

一件不一致があっても別の検査経験が比較不能なら全体DEFERとし、不一致自体は診断へ残す。
完全に検査できた集合に対する許容不一致数0の規則であり、少数の一致による多数決ではない。
複数理由を保持する。検査結果には比較完了フラグ、各組の結果、形成支持数と検査件数を別々に記録する。
検査経験をCandidate支持へ追加したりCandidateを作り直したりしない。
REJECTでも履歴・Bias・Candidateは削除せず、RETAINでも対象の一般化・因果・普遍性を認定しない。

## 6. 純粋評価と明示記録

純粋入口案: `evaluate_neural_t1_selection(...)`。
出力schemaは`nerv-t1-selection-evaluation-v1`。全入力出典、対応記述、規則版、診断、relation別dispositionを返す。
同じ内容の順序入替で結果IDを変えず、入力やstoreを変更しない。

明示記録入口案: `record_neural_t1_selection(...)`。
内部で再評価し、既存`T1MaterialSelectionLedger.inspect`の全材料レビューへ変換する。
bundleのcanonical4材料は、この局所Food検査では評価対象外として全件DEFER、basisに`canonical_material_out_of_scope`を記録する。
勝手にRETAINにせず、かといってレビューから欠落させない。
神経子材料は上記結果を使用し、全材料へちょうど1件ずつbasis/evidence付きで渡す。
構造化診断全体は確定JSONとしてevidenceに保存して追跡できるようにする。新しい永続診断storeは作らない。

revisionは既存ledger仕様を維持し、明示再検査はexpected_revision一致で1増加。
同じexpected_revisionの再送はstaleとして拒否する。冪等な再送受付と誤記しない。
再検査でも形成支持数や経験数を増やさない。容量・改変・重複/欠落の拒否で部分reviewを公開しない。
既存ledgerは最新版保持であり、過去revisionの永続監査履歴を保証しない。

## 7. 信頼境界と再構成への非接続

呼出し側が現行bundle/model/ledgerを渡す責務を持つ。参照整合性と出典再現を検査するが、偽造snapshotを外部認証する仕組みではない。
専用モデルfixtureも実運転の意味的妥当性を証明しない。
既存汎用T1-Cには独立した明示入口があるため、「任意の呼出しでも再構成不能」とは主張しない。
NERV-4Cの正式経路からT1-C/cutoverを呼ばないことを受入で確認する。
canonical材料をDEFERにすること自体を、将来にわたる再構成禁止の技術的ロックとは扱わない。

## 8. 実装時の受入条件

**全件未実施。**

| ID | 必須検査 |
| --- | --- |
| N4C-01 | 対応次元なしの現行モデルはDEFER、明示Foodモデルfixtureで対応を検証 |
| N4C-02 | 未使用経験の一致でRETAIN、非zero不一致でREJECT、経験不足/比較不能でDEFER |
| N4C-03 | 正負両方向の再現、不一致と比較不能の併存、複数理由の保持 |
| N4C-04 | raw/neural依存、形成支持数と検査件数の分離、filtered関係の復活なし |
| N4C-05 | 形成/検査のExperience・event重複、未知・改変・混線・規則不整合拒否 |
| N4C-06 | 最大6検査経験、前段上限、切り詰めなし、順序不変IDと入出力独立 |
| N4C-07 | canonical4材料を含む全件review、各basis/evidenceから診断追跡可能 |
| N4C-08 | expected_revisionと容量検査、拒否時の部分更新なし、再検査で支持不増 |
| N4C-09 | 純粋評価で全store不変、記録でT1-Bのみ変化、T1-A/モデル/神経保存state不変 |
| N4C-10 | T1-C/cutover自動呼出しなし、Action/履歴/既存Sleep非介入、全体回帰PASS |

Python fixtureによる有限選別を対象とする。実Luanti/HTTP・自律注意・行動差・長期運転は対象外。
この受入が通っても、実NPCモデルへの神経relation採用や神経系全体の完成とはしない。
