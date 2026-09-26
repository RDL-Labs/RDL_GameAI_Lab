# NERV-4A 神経由来profileの有限比較・Candidate契約

状態: DESIGN ONLY / 未実装・受入未実施 / 2026-09-26。
基準: `f78731a6`（NERV-3）。[前段Evidence](../experiment-evidence/NERV_3_neural_bias_admission_evidence.md)。
NERV-4の「個体差」へ向けたPython再生の初回断面であり、実Worldの自律的な経験差・長期保持を完成扱いにしない。

## 1. 問いと終了点

同じrun・個体・固定神経parameter・同じ文脈の、明示指定した異なる経験について、
**全指定経験に共通して残った非zeroの知覚関係は何か**。
この有限な共通関係を、出典を保持したGameAI-local Candidateとして返す。

```text
NERV-3の受理済み材料
→ 同じ専用compilerでSleep profileを再構成
→ 明示Experience集合の比較条件を検査
→ 共通関係と、不一致・抑制・zeroの記録
→ 有限Candidate / 候補なし / 比較不能 / 経験数不足
```

候補が必ず変わる、常に1つへ収束することを成功条件にしない。
NERV-3の既定動作、raw Bias/旧Sleep、既存Deep Similarity・T1は変更しない。
今回の到達点は純粋な候補形成結果まで。HTTP、Luanti、常駐hook、永続store、支持数の累積は作らない。

## 2. 入口と信頼境界

入口案: `build_neural_candidate(materials, request)`。
materialsは`NeuralOutcomeCoordinator.sleep_materials(agent_id)`のコピー。
任意のprofile辞書をそのまま信用せず、`compile_neural_sleep_profile`で完全性と出典を検査してから選択する。
未選択の不正材料も見逃さない。外部の真正性を認証する署名ではなく、受理済み材料の整合性検査である。

requestはrun_id、agent_id、parameter_id、parameter_revision、rule_version、
明示的なsource_experience_ids、sleep_cycle、formation_tickを持つ案。
規則版は`nerv-common-relations-v1`。IDは空でない128文字以内、revision=1、
formation_tickは非負の整数（bool不可）。run/個体/parameter全内容は材料と一致させる。
生成時tickは呼出しmetadataであり、これだけで時間的因果や経過時間を推定しない。

未知・重複Experience ID、不正型、改変・重複projection、別run/個体、混在parameter、旧raw/preview schemaは明示拒否。
同じExperienceの再送を重複排除して成功扱いにせず、重複指定は入力誤りとする。
同一個体のparameter比較は別instance/別再生条件で行う。運転中parameter変更を追加しない。

## 3. 有限予算と選択

前段の材料上限を維持: projection最大128、Bias最大32。超過はcompilerが拒否し、切り詰めない。
requestのExperience IDは最大6件、重複処理前に予算検査。暗黙の最新6件や全履歴総当たりはしない。
0〜2件の正当な選択は`insufficient_experiences`、3〜6件で比較する。
選択にはBiasが0件のExperienceも含められる。profile一覧だけでなくprojection summaryから参照する。
全抑制の経験を選択集合から自動除外して支持を作り直さない。

3〜6経験の全対比較は最大15組、各4関係で最大60判定。Candidateは最大1件、共通関係は最大4件。
出力は指定集合に有効な結果であり、選択外の履歴の代表や最良候補ではない。

## 4. 比較適格性と関係の判定

全指定経験が同じ固定parameterで処理されていることを確認する。
context_signatureはraw出典から取り、正規化したJSON構造の完全一致を要求する。
初版は既存Risky Tasty Foodのcontext（food_id=tasty_food）に限定。
許可外の文脈や文脈差は正常な`not_comparable`とし、候補探索を完了した扱いにしない。
不足した文脈をWorld問い合わせ・ID解析で補わない。

この問いは異なる経験に繰り返し残る関係を調べるものなので、OBS-7Aの時間重なり条件を適用しない。
一方、同時経験、同じ物体、因果関係、定常な環境を証明するものでもない。

各関係のsignatureはrelation/direction/strength/magnitude/context_signature。
知覚値はNERV-2を維持し、加算・平均・重み付け・ランキングをしない。
全指定経験で同じ非zero signatureがあれば、その関係を共通集合へ入れる。
それ以外の関係はCandidateから外すが、理由と出典を必ず残す。

| 状態 | 診断上の扱い |
| --- | --- |
| 同じ非zero値 | 一致。異なるExperienceごとに最大1支持 |
| 非zeroで同方向・強度差 | `strength_difference`。共通signatureなし |
| 非zeroで方向差 | `direction_conflict`。符号差あり |
| raw非zero→神経抑制で0 | `neural_filtered`。未支持であり反証とは扱わない。NERV-2の両抑制理由を保持 |
| raw自体0 | `raw_zero`。未支持、経験の不存在とは扱わない |

一組で複数理由がある場合も消さない。知覚0のneutralを、非zeroの符号反転と扱わない。
例えば4経験のうち3件が一致し1件が抑制された場合、その関係は「全4件に共通」の条件を満たさず候補に入らない。
一致3件の参照は診断に残し、4件目を反証や不存在と解釈しない。他の共通関係があればそれは保持する。

## 5. 結果とCandidate出典

結果状態:

- `insufficient_experiences`: 正当な選択だが3件未満。
- `not_comparable`: 文脈条件がそろわない。候補はnull、comparison_complete=false。
- `no_candidate`: 比較完了、全指定経験に共通する非zero関係が0件。
- `candidate_formed`: 比較完了、共通関係が1件以上。

入力拒否をこの4状態に混ぜない。抑制/zeroを含めて各関係の状態を調べ終えた場合はcomparison_complete=true。
no_candidateは無学習・安全・失敗の判定ではない。全抑制やraw zeroの内訳は診断に残す。

Candidate schema案は`nerv-relation-candidate-v1`。旧Candidate schemaに偽装しない。
run/agent/parameter全内容、規則版、sleep_cycle、formation_tick、選択Experience ID、
raw/projection/profile/Bias/event参照、共通signature、関係別support Experience IDを保持する。
存在しないprofile/Bias IDを補完しない。支持数は各関係について異なるExperience数（3〜6）。
relation数、同じeventの再送、Sleep呼出し回数を足さない。

IDは規則・選択元の全内容・parameter・出力条件から決定し、順序の入替で変えない。
同じ条件の再評価は同じ結果。別sleep_cycle/tickで識別が変わっても新経験の支持とは数えない。
入力・保存材料・出力間のmutable aliasを禁止する。
出力のauthorityは局所的Candidate記録に限定し、canonical CandidateRelationやT1材料へ自動昇格しない。

## 6. 受入条件

全件未実施。Pythonの既存event形成→NERV-3受付→材料compiler→本比較器という経路を通す。

| ID | 必須検査 |
| --- | --- |
| N4A-01 | 同一結果列の四隅parameterでCandidateの共通関係差を確認。HIGH等で差がない場合も正常 |
| N4A-02 | 支持数は3〜6個のdistinct Experience。relation数・再送・再Sleepで増えない |
| N4A-03 | 抑制・raw zero・強度差・符号差を分離し、複数理由を保持 |
| N4A-04 | 0〜2経験、比較不能、候補なし、候補ありの各状態 |
| N4A-05 | 未知/重複ID、run/agent/parameter混線、改変・材料欠落・旧schemaを拒否 |
| N4A-06 | 最大6経験/15組/60関係判定、7件指定と前段上限超過を拒否 |
| N4A-07 | 全抑制経験を選択から消さず、3一致+1抑制で不当な共通関係を作らない |
| N4A-08 | 全参照・固定parameter・規則を追跡可能。同一再生ID・順序不変・入出力独立 |
| N4A-09 | 旧Sleep/Deep/T1の許可schemaを広げず、新Candidateを既存T1投影が拒否 |
| N4A-10 | 候補形成の有無で保存state・既存行動・canonicalが不変。全体回帰PASS |

全抑制、raw全zero、通常生成器が出さない強度などは合成fixtureとして明示する。
実Luantiの長期運転・自律的個体差・行動変化は今回の受入に含めない。

## 7. 停止境界

全受入PASSで神経由来profileの有限比較と局所Candidateまで固定する。
T1へ渡す場合は、raw根拠と神経条件に依存する知覚根拠をどう検査・選別するかの別契約が必要。
候補の存在だけでM_B更新・Goal優先度・Trajectory生成を変更しない。
観測基盤v1・NERV-1/2・NERV-3の既定条件は維持する。
