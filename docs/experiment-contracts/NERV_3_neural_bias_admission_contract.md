# NERV-3 知覚勾配からLocal Biasへの明示接続契約

状態: IMPLEMENTED / N3-01〜10 PASS / 2026-09-26。
実行結果と合成試験の限定は[Evidence](../experiment-evidence/NERV_3_neural_bias_admission_evidence.md)を参照。
基準: `b7c3eeed`（NERV-1/2）。Observation v1は`8616fe7e`で固定。
[前段のEvidence](../experiment-evidence/NERV_1_2_neural_gradient_projection_evidence.md)を前提にする。

## 1. 問いと到達点

同じ有限な結果を異なる固定神経parameterで処理し、知覚勾配から形成された関係Biasを
一度だけ保存し、その出典と抑制を保ったままSleep用関係profileへ渡せるか。

```text
明示的に選んだneural mode
→ Experience / raw Outcome Gradient（保存）
→ NERV-2 perceived gradient（保存）
→ neural-origin Local Bias（保存）
→ Sleep入力の関係profile（明示呼出し）
```

初版はPythonのopt-in coordinatorで検証する。HTTP endpoint・CLI既定切替・Luanti身体作用は追加しない。
Sleepの類似度、支持回数によるCandidate生成、T1、M_B更新、Goal、Trajectory、Actionへの接続は保留。
関係profileまでを実際に保存・引渡しするが、睡眠の全工程が神経対応になったとは呼ばない。

## 2. 既定経路と固定設定

現行`LuantiOutcomeCoordinator()`のraw→既存LocalBiasStore→既存Sleep経路は既定のまま。
新入口は`NeuralOutcomeCoordinator(run_id, parameters)`。継承で旧T1権限を引き継がず、
必要な既存Experience/raw形成器とNERV-2を明示的に組み合わせる。
run ID、最大16個体のparameterを構築時に検証・固定する。未割当個体は拒否し、rawへのfallbackをしない。
同一instance内のmode切替・parameter変更・動的profile更新は初版で許可しない。

同一eventをraw/neural両経路へ暗黙に二重投入しない。比較実験だけは独立したinstanceで同じfixtureを再生する。
それぞれのID・schema・出典を分け、同じ学習材料の支持数を倍増させない。
NERV-1/2のpreview自体を保存入力には使わず、coordinator所有の受理済みrawからprojectionを計算する。

## 3. 保存schemaと出典

専用schema:

- 知覚勾配: `nerv-perceived-gradient-v1`（NERV-2の値・規則を維持）。
- 保存Bias: `nerv-local-bias-v1`。preview schemaとも旧raw Bias schemaとも異なる。
- Sleep用profile: `nerv-local-bias-relation-profile-v1`。既存compilerへ暗黙に許可を追加しない。

Biasは非zeroの知覚関係から最大4件形成する。relation/direction/strength/magnitudeを写し、
run/agent、raw gradient、projection、Experience/event、parameter ID/版/値、規則版を保持する。
raw contextも保持する。Bias IDはrun・projection・relationから決定し、異なる由来を同一IDにしない。
NERV-2の抑制理由は保存projectionへ残す。Biasが0件でもprojectionと受付記録は残す。
「学習材料なし」「全関係が抑制」「出典不正」「容量拒否」を同じ空配列で返さない。

raw gradientは神経値で上書きしない。知覚勾配の値をraw schemaへ詰め直して旧`LocalBiasStore.form`へ渡さない。
入力・保存・返却snapshot間のmutable aliasを禁止。IDは再現性のためであり外部署名ではない。

## 4. 一回受付とatomicな更新

`record(payload)`は既存と同じ有限event/outcome_factsを受ける。
受付identityは(run_id, agent_id, event_id)。同一identity・同一payload・同一固定設定の再送は同じ結果を返す。
再送でExperience/raw/projection/Biasの件数、強度、Sleep入力数を増やさない。
同一identityの内容変更は明示拒否。過去のpayload fingerprintと結果を有限台帳に保持する。

初版容量はinstance全体で、個体16、受付台帳128、Experience128、raw128、projection128、Bias256。
退避・eviction・永続化は追加しない。各既存storeの小さい上限がある場合も拡大せず、先に拒否する。
重複再送は容量判定より先に照合し、満杯でも既存結果を取得できる。

一つのeventの全関係について必要容量と整合性を事前検査し、全段階成功時だけ公開状態を更新する。
途中で失敗してExperienceだけ増える、4Bias中2件だけ入る、失敗をaccepted=trueにする挙動を禁止。
staging中の既存形成器による変更も公開storeへ漏らさない。拒否カウンタは診断軸として別に扱う。
空のBias集合は容量を消費しないが、projection・受付台帳等は1件分消費する。

## 5. Sleepへ渡す範囲

入口`build_sleep_profile(agent_id)`は保存済みneural Biasだけを読む純粋な専用compiler。
1呼出し最大32Bias。上限超過は拒否し、暗黙の先頭32件・最新32件を選ばない。
別個体・別run・旧raw schema・preview schemaの混入を拒否する。
同じExperienceを単位として関係profileを形成し、全relationへprojectionとparameterの出典を保持する。
同じExperienceの複数relationを複数経験の支持と数えない。

出力は検査用のSleep入力まで。保存projectionが存在して全関係抑制なら`all_relations_filtered`、
まだExperienceがなければ`no_experience`をmetadataで区別する。profile0件を安全・成功と解釈しない。
raw由来の既存Sleep、Deep Similarity、T1が新schemaを受け入れるようには変更しない。
既存のneutral条件と比較するのは関係値・groupingのみで、schema/IDの同一性は要求しない。

## 6. 受入条件

全件PASS。今回は既存Python fixtureから受理した有限eventで検証し、実World個体差とは区別する。

| ID | 必須検査 |
| --- | --- |
| N3-01 | 既定raw coordinatorの受付結果・Bias・Sleep・canonicalが変更前と一致 |
| N3-02 | NERV-2四隅の差が保存Biasへ反映され、raw/Experience事実は同一条件で保持 |
| N3-03 | 中立parameterのBias関係値が旧経路と一致。ID/schemaは分離 |
| N3-04 | 正確再送で全store・台帳・profile件数が増えず、満杯時も再送可 |
| N3-05 | 同event内容変更、run/個体混線、parameter未割当・再設定を拒否 |
| N3-06 | 各容量の直前/到達/超過、途中段階の失敗注入で公開状態の部分更新なし |
| N3-07 | Bias0件でもprojection/理由/受付を保持。無経験と抑制、拒否を区別 |
| N3-08 | Sleep profileへ出典を保持し、最大32件境界・schema混入・別個体を拒否 |
| N3-09 | 既存action・Goal・canonical・旧Sleepへの非介入。新schemaの暗黙昇格なし |
| N3-10 | 入出力の独立性、再生順序で変わらない関係値、全体回帰PASS |

既存のevent/outcome入力が作れない全zeroなどの境界は合成試験と明記する。
NERV-1/2、Outcome/Bias、Luanti学習、OBS系列の保存記録回帰を含む全体試験を実行する。
本番のHTTP・Luanti経路へ接続しないため、初版の完了証拠はPython再生とし、実機試験と混同しない。

## 7. 終了条件

全受入PASSで「神経由来Biasの有限保存とSleep入力profile」まで固定して止める。
Candidate形成・支持閾値・T1への昇格には神経出典をどう扱うかの別契約が必要。
予測誤差・F/E/H・theta_effへの同一視、一般人格・探索性・行動差の主張をしない。
Observation v1の完了条件へ追加要件を戻さない。

## 8. 実装時に固定した詳細

入口は`runtime/neural_outcome.py`。構築時の`capacities`は既定以下の縮小だけを許可する。
公開設定はread-only。stagingとstate参照の一回置換をprocess内ロックで保護する。
`record`のpayloadはevent/outcome_factsの2field。runはcoordinator所有のscopeであり、World run認証ではない。
`sleep_materials(agent_id)`は保存済み材料のコピー、`build_sleep_profile(agent_id)`は専用compilerの結果を返す。
全zeroは`no_nonzero_relations`として全抑制と区別する。全抑制と全zeroの受入は合成試験。
profileは保存Biasから明示呼出し時に生成し、追加の永続storeへ保存しない。
18テストPASS、全体440件（394 PASS / 46 intentional skips）。実機・HTTP接続は対象外。
