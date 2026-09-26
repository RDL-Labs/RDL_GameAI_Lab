# NERV-1/2 神経感度・知覚勾配の有限再生契約

状態: DESIGN ONLY / 未実装・受入未実施 / 2026-09-26。
基準: Observation v1 COMPLETE `8616fe7ea43c6b987c1f61b36b3c9ef9e946e83f`。
本契約はGameAI-localの初回検証案。神経生理学的モデルやcanonical解釈の実装ではない。

## 1. 問いと停止境界

同じ有限な結果記録を、異なる固定神経パラメータで処理したとき、
どの関係への反応が残り、どの関係のBias形成が抑制されるかを再現可能に検査する。

```text
受理済みExperience + outcome facts
→ 既存OutcomeGradientStoreのraw記録（不変）
→ 明示した個体別固定parameter
→ pure perceived gradient
→ pure shadow Bias preview
```

初回実装範囲はNERV-1の固定container、NERV-2の純粋projection、検査専用Bias previewまで。
NERV-3の本番LocalBiasStoreへの接続、Sleep、Candidate、T1、Goal、Trajectory、Actionは保留。
観測系の追加実装、OBS-7A/7Bからの自動起動、HTTP endpoint、GUI、常駐hookは作らない。
将来roadmapの神経系全体に対する保留を解除するものではなく、この有限再生だけを次の実装候補とする。

## 2. 現行コードから分かった制約

`runtime/outcome_bias.py`のrawは全体報酬scalarではない。
`acquisition / return / injury / reward_value`の4関係に対し、directionと
magnitude 0/1/2/3（ZERO/WEAK/MEDIUM/STRONG）を持つ。
現行LocalBiasStoreは非zero関係をそのままBiasへ写す。加算学習・時間減衰ではない。
`runtime/luanti_outcome.py`はraw→Biasを直接呼ぶため、ここへ暗黙に割り込まない。
既存`runtime/sensitivity.py`のretry profileも神経parameterと混同しない。

このrawに予測値・予測誤差・canonical Eはない。したがって初版の`error_sensitivity`は
**既存の有限な結果差の小さい段階まで反応対象へ残す感度**という局所的な操作定義とする。
予測誤差への感度を実装したとは呼ばない。将来その意味を拡張するときは別入力契約・別規則版を必要とする。
0〜3は順序尺度として扱い、掛け算、総和、平均、連続量への補間をしない。

## 3. 固定parameterと作用表

parameter案: `agent_id / parameter_id / revision / error_sensitivity / reward_threshold`。
前3項は所有と再現のmetadata。作用する軸は後2項だけ。
revisionは初版1、IDは空でない128文字以内、真偽値・float・NaN・未知fieldは拒否。
error_sensitivityは整数1/2/3、reward_thresholdは整数0/1/2/3。
fixture開始時に固定し、同じ個体へ途中で別parameterを上書きしない。DNA・動的状態は導入しない。

| error_sensitivity | 反応に残す最小raw magnitude |
| --- | --- |
| 1（低） | 3 |
| 2 | 2 |
| 3（高） | 1 |

各関係を独立に評価する。規則版案は`nerv-perceived-gradient-v1`。

1. raw magnitude=0は0のまま。理由`raw_zero`。欠落値を0に補完しない。
2. 正負を問わず、raw magnitudeが感度表の最小値未満なら抑制。理由`sensitivity_filtered`。
3. **正方向のreward_valueだけ**、raw magnitude < reward_thresholdなら抑制。理由`reward_below_threshold`。閾値ちょうどは通す。
4. 2と3は元のraw値から独立に検査し、両方不成立なら両理由を保持する。
5. 全条件を満たせば元のmagnitude/directionを維持。抑制ならperceived magnitude=0・direction=neutralとし、元の値も別fieldで残す。

報酬閾値を成功一般のacquisition/return、負方向のinjuryへ適用しない。
符号反転、負傷の正報酬化、非zeroへの増幅は行わない。抑制は「事実がなかった」「安全だ」の意味ではない。
初版は損失専用の追加軸を持たず、共通感度が正負双方へ作用する。
中立基準はsensitivity=3 / threshold=0。この条件でperceivedの関係値はrawと一致する。

## 4. 入力・出力・出典

入口案: `project_perceived_gradient(raw_snapshot, request, parameter)`。
requestは同run内で明示したagent_idとsource_gradient_id、規則版を持つ。
raw_snapshotは既存storeから取り出した有限な受理済み記録を使用。World完全情報を問い合わせない。
未知/重複ID、他個体の参照、parameter所有不一致、不正bandとmagnitudeの対応、欠落/重複関係は明示拒否。
全4関係を要求し、関係順序を固定して決定的に出力する。入力dictやsnapshotを変更しない。

出力は専用schemaとprojection ID、agent_id、source_gradient_id、Experience/event参照、
parameter ID/版/値、規則版、各関係のraw値・perceived値・理由を保持する。
projection IDは出典・parameter全内容・規則版から決定し、異なる条件が同IDを再利用しない。
同じ入力の再評価は同じ出力を返す。出力から入力へのmutable aliasを残さない。

同じraw記録を他個体へ無断で使い回さない。
個体差の対照実験は、同じfixture caseからA/Bそれぞれの正当なExperienceとrawを形成する。
agent/Experience/event IDは各自固有、outcome factsと4関係値は同一として比較し、
共通case IDは実験者の対応表だけに置く。同じeventを双方が実際に経験した証明とはしない。
同一agentのparameter対照も、独立した再生条件として扱い、運転中のparameter更新とは区別する。

## 5. Shadow Bias preview

入口案: `preview_neural_bias(perceived)`。perceived専用schemaを明示検査する純粋関数。
非zero関係ごとにdirection・strength・magnitudeを写し、source_projection_idとraw参照を残す。
通常のLocalBiasと異なるschemaを使い、既存LocalBiasStoreやSleepへの入力に偽装しない。
空のpreviewは「反応条件を通過する関係がない」であり、raw記録の欠落や安全判定ではない。

中立parameterでは既存`LocalBiasStore.form(raw)`と関係値が一致することを試験する。
比較対象はrelation/direction/strength/magnitude。IDとschema・権限は異なる。
初版が示すのはBias**形成差のpreview**までであり、本番Bias更新や行動差ではない。

## 6. 有限予算と試験案

単発projectionは1記録・4関係、preview最大4件。replay runnerは最大16parameter、
64件の明示した（raw参照・parameter）組、raw snapshot最大128件。重複排除前に上限検査する。
全履歴総当たり・暗黙の最新選択・永続store・累積支持回数は追加しない。
不正入力や容量超過で部分出力を成功扱いせず、runnerは全入力検証後に結果を返す。

四隅の対照は(sensitivity, threshold)=(1,1)/(1,3)/(3,1)/(3,3)。
NORMAL取得報酬（magnitude=2）は高感度・低閾値だけが残る。
light injury（magnitude=1）は高感度で残り、報酬閾値には左右されない。
HIGH報酬（3）は四隅全てに残る。ゼロは全てゼロ。同じ出力になる場合も正常結果として残す。
現行raw生成器はreward_value=1を生成しないため、閾値境界1の全数検査は合成入力試験と明記する。

| ID | 受入条件（全て未実施） |
| --- | --- |
| N12-01 | 既存storeで形成したrawを読み、入力・Experience・raw snapshotを変更しない |
| N12-02 | parameter所有・型・版・範囲、不正参照・重複関係・未知schemaを拒否 |
| N12-03 | magnitude 0〜3 × sensitivity 1〜3 × threshold 0〜3の境界表を検査。真偽値は整数として受けない |
| N12-04 | 二軸の四隅比較でNORMAL報酬/light injuryの差とHIGHの同値を確認 |
| N12-05 | 閾値は正reward_valueのみ。負傷を正報酬にせず、事実値を保存 |
| N12-06 | 二つの抑制理由を同時保持。zero・不正入力・抑制を区別 |
| N12-07 | 中立条件のpreviewが既存Biasの関係値と一致し、既存経路は不変 |
| N12-08 | 同一再生は同一ID/値、異なるparameterは別出典、入力・出力の独立性 |
| N12-09 | A/Bの参照分離、parameter順序に依存しない対応結果、予算の境界/超過拒否 |
| N12-10 | 固定packetの行動応答・Experience・通常Bias・Sleep・canonicalがprojection呼出し有無で一致 |

最初はPythonの有限再生試験。実Luantiの自律行動差・実World個体差を検証したとは記載しない。
既存Outcome/Bias・Luanti学習・OBS-7A/7B/8/8B/9の保存記録再生を含む全体回帰を実行する。
実機再実行が必要になる接続変更を、この初回には含めない。

## 7. RDL上の境界と終了条件

perceived gradientはcanonical Eではない。error_sensitivityはρ・Hではなく、reward_thresholdはtheta_effではない。
観測が到着しただけでFを形成した扱いにしない。Purpose/B/Section_B、同じ更新前M_BによるF/F'比較は別契約。
この段階からCandidateRelation、M_B更新、Goal選択へ自動昇格させない。
全受入が通ったらNERV-1/2とshadow previewで停止し、NERV-3の接続先・一回更新・保持・Sleepへの受渡しを別途定める。
観測基盤v1の完了条件は変更しない。
