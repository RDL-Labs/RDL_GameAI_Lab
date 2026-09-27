# NERV-4D 固定個体条件による選別許容度の契約

状態: **DESIGN ONLY / 未実装・受入未実施** / 2026-09-27。
基準: `49b2ee5c`。[NERV-4C Evidence](../experiment-evidence/NERV_4C_neural_T1_selection_evidence.md)。

## 1. 問いと停止点

同じCandidate・検査経験・モデル対応について、検査された事実を変更せず、
固定した個体別Selection条件だけでRETAIN/REJECTが変わるか。
初版はacquisitionに対する**許容不一致率**の一軸のみ。
身体・履歴からの動的条件、defer/probe傾向、relation persistence、感情ラベルは追加しない。
到達点は有限選別結果と明示T1-B記録。T1-C、M_B更新、行動差には接続しない。
これは「選別条件差」の実験であり、感情そのものを実装・実証したという主張ではない。

## 2. 検査と許容判断を分ける

既存`evaluate_neural_t1_selection`を内部で実行し、出典・bundle・モデル対応・未使用経験を再検証する。
呼出し側が持ち込んだ診断辞書を検査済みとして受け取らない。
NERV-4Cの規則と`allowed_mismatches=0`を変更しない。
新しい規則版`nerv-food-acquisition-tolerance-v1`の出力は、元の4C結果全体を`baseline_evaluation`として保持する。

```text
同じ記録
→ NERV-4Cの固定検査と許容0の基準結果
→ 固定SelectionProfileによる別の許容判断
→ 新しいdisposition + 反例を含む全根拠
```

基準結果のREJECTを削除・上書きせず、新規則でRETAINになった場合も両方を追跡できるようにする。
RETAINの理由は「完全再現」と「不一致はあるが許容範囲内」を区別する。
raw/neuralの知覚値・pair_results・比較可能性・形成支持数・検査件数は変えない。

## 3. 固定SelectionProfile

schema案: `nerv-selection-profile-v1`。
厳密なfieldはagent_id、profile_id、revision、tolerance_numerator、tolerance_denominator。
IDは空でない128文字以内、revisionは整数1。boolを整数として受けない。
初版の許可値は既約分数の**0/1と1/3のみ**。float、負数、分母0、等価な別表現2/6、未定義fieldは拒否。

これはNERV-1/2のNeuralParameterとは別の条件であり、感度や報酬閾値から暗黙生成しない。
`NeuralSelectionTendencyEvaluator(run_id, profile)`のように構築時に一つのrun/個体/profile全内容を固定する。
評価時のprofile差替え口を作らず、公開内容を変更しても内部条件は変わらない。
入力のrun/agentが固定条件と一致しなければ拒否。

同じ記録で二条件を比較する際は、別の独立した評価instance/ledgerで再生する。
同run/agentに二つの設定を持つ再生は反実仮想の条件比較であり、運転中の個体条件変更ではない。
全プロセス共通の一意registry・永続profile管理は作らない。
実際に異なる個体で試す際は、それぞれが所有する記録を使い、agent IDの書換えで入力を共有しない。

## 4. 有限判定

4Cでcomparison_complete=trueになったacquisitionのみ対象。
比較不能・対応不足・経験なし・対象外relation・canonical材料のDEFERは、その理由ごと維持する。
raw zero等の規則不整合は前段と同じ入力拒否であり、許容度で通さない。

n=比較した検査経験数（1〜6）、k=matched=falseの数。
許容分数をp/qとし、**k*q <= n*p**ならRETAIN、それ以外はREJECT。
浮動小数の丸めは使わない。各経験を等重みとし、反例の重み付け・多数決・ランキングは追加しない。

| 検査結果 | 0/1 | 1/3 |
| --- | --- | --- |
| 0/3不一致 | RETAIN（完全一致） | RETAIN（完全一致） |
| 1/3不一致 | REJECT | RETAIN（許容範囲内） |
| 2/3不一致 | REJECT | REJECT |
| 1/2不一致 | REJECT | REJECT |
| 2/6不一致 | REJECT | RETAIN（境界値） |
| 3/6不一致 | REJECT | REJECT |
| 反例あり＋別経験がcontext不一致 | DEFER | DEFER |

正負の取得結果に対称に適用する。全件反例を許可する設定は初版にない。
不一致率はこの有限検査集合の記述であり、母集団の失敗確率・身体損害・期待効用ではない。
ここでのloss toleranceは取得結果relationの再現不一致を許す比率の局所的名称である。

## 5. 出力と出典

出力schema案: `nerv-t1-tolerance-evaluation-v1`。
規則版、固定run/profile全内容、baseline_evaluation、材料別disposition、基準disposition、
comparison_complete、k/n、許容p/q、判定理由、形成支持数と検査件数を別々に保持する。
比較不能/対象外材料ではkと判定用nをnullとし、部分結果を完全な不一致率として提示しない。
元のvalidation_countとpair_resultsはbaselineから追跡する。

理由案:

- `exact_recurrence`: k=0でRETAIN。
- `within_declared_tolerance`: k>0で許容範囲内のRETAIN。
- `exceeds_declared_tolerance`: 許容超過のREJECT。
- DEFER: 基準の全理由を維持。

IDは規則・profile全内容・基準結果全内容から決定する。入力順で変えずmutable aliasを作らない。
同じ判定でもprofileが異なれば結果IDは異なり得る。判定差と識別差を混同しない。
profileの違いを新しい経験や支持として数えず、反例も元のまま残す。

## 6. T1-B明示記録

評価だけではstoreを変更しない。明示record入口は同じ固定instanceで再評価し、全材料レビューを既存ledgerへ渡す。
reviewer/expected_revisionは必須。basisに新規則の理由、evidenceに基準結果とprofileを含む確定JSONを保存する。
凍結済み4B bundleのbinding/criteria_refや4C targetの許容0を書き換えない。
新profileと規則版が、基準criteriaに追加した選別条件であることをrecordから追跡できるようにする。
これは呼出し側が明示的に新しい選別規則を選んだ記録であり、既存criteriaの意味を密かに変更するものではない。

同じexpected_revisionの再送は拒否、次revisionの明示再検査のみ進む。
既存ledgerの最大128件と拒否時の部分更新なしを維持し、支持数を累積しない。
最新版保持であり、過去revision全件の永続履歴ではない。
汎用ledgerを直接呼ぶ外部コードまでprofile固定を強制するセキュリティ境界とはしない。

## 7. 予算・信頼境界・非接続

形成経験3〜6、検査経験最大6、全材料最大8、前段128 projection/32 Bias上限を維持。
今回profileを大量に総当たりするAPIは追加しない。二条件の比較は明示的な2回の有限再生とする。
モデル対応の正例は4Cと同じ専用合成Foodモデルfixtureを使う。
実NPCの個数観測モデルでは対応を補わずDEFERを維持する。

snapshotの現行性・真正性は呼出し側の責務。前段の出典再現検査を維持する。
T1-C/cutoverを自動呼出ししない。神経保存state、旧Sleep、canonicalモデル、Actionは変えない。
身体・履歴が許容度を変える機構や、自律注意・Probe起動は別契約とする。

## 8. 実装時の受入条件

**全件未実施。**

| ID | 必須検査 |
| --- | --- |
| N4D-01 | 同一基準結果で0/1と1/3の判断差。raw/neural/pairs/支持は一致 |
| N4D-02 | 0/3、1/3、2/3、1/2、2/6、3/6と正負対称性、整数境界 |
| N4D-03 | mapping不足・context差・経験なし・他relation/canonicalのDEFER維持 |
| N4D-04 | 反例と比較不能の併存はDEFER。部分率を完全な率として出さない |
| N4D-05 | 不正profile・run/agent混線・再割当拒否、固定値と返却値の独立 |
| N4D-06 | 改変・経験/event重複・前段上限を維持、外部診断辞書の直接受付なし |
| N4D-07 | profile/基準/new disposition全出典、順序不変ID、非alias |
| N4D-08 | 全材料の明示記録、revision/容量/部分更新なし、profile差で支持不増 |
| N4D-09 | 純粋評価でstate不変、記録時T1-Bのみ変更、T1-C/cutover非呼出し |
| N4D-10 | 4C許容0の既存結果不変、旧Sleep・Action・canonical回帰PASS |

実装後も主張は「固定選別条件による有限判断差」まで。感情・性格・自律学習・行動差の完成ではない。

## SOC実験との関係

[SOC-2契約](SOC_2_rescue_selection_tolerance_contract.md)は同じ検査/許容判断の分離を、
共同搬送の有限記録で調べる別実験として実装・受入済み。Food acquisitionを前提とする本契約へSOC記録を流用しない。
SOC-2の局所選別はcanonical T1-Bではなく、NERV-4Dの実装・受入を兼ねない。本契約はDESIGN ONLYを維持する。
両方とも固定条件の比較であり、神経・身体・履歴から条件を動的に生成する層は未接続。
