# NERV-3 神経由来Bias保存・Sleep入力 Evidence

状態: **PASS / N3-01〜10完了 / Sleep入力profileまで固定** / 2026-09-26。
実装開始点: `ac441779`。[契約](../experiment-contracts/NERV_3_neural_bias_admission_contract.md)に対応。
Observation v1は`8616fe7e`、NERV-1/2は`b7c3eeed`の範囲を維持する。

## 今回実装した範囲

`runtime/neural_outcome.py`に独立した`NeuralOutcomeCoordinator`を追加した。
既存`LuantiOutcomeCoordinator`の継承・置換・自動切替は行わない。

```text
coordinator構築時の固定run/parameter
→ record({event, outcome_facts})
→ 既存Experience/raw形成器
→ NERV-2知覚勾配
→ 専用neural Biasを保存
→ build_sleep_profile(agent_id)を明示呼出し
```

保存Biasは`nerv-local-bias-v1`、Sleep profileは`nerv-local-bias-relation-profile-v1`。
previewを保存入力にはせず、所有するrawから知覚勾配を作る。
元のraw・Experienceを保持し、Biasごとにprojection/raw/Experience/event/parameter全内容/規則版/run/agent/contextを残す。
Sleep profileは保存材料から呼出し時に純粋に生成する。profileを別の永続storeへ蓄積しない。

## 一回受付と失敗時の状態

公開状態はExperience・raw・projection・Bias・受付台帳を含む一つのstate。
recordはロック下で既存受付を照合し、未受付ならstate全体のコピー上で形成・検証する。
必要容量を確認し、返却値のコピーも成功した後にstate参照を一度だけ置換する。

- 同(run, agent, event ID)・同payloadの再送は保存済み結果を返し、満杯でも件数を増やさない。
- 同identityの内容変更は`event_conflict`。未割当個体や余分なpayload fieldも拒否する。
- Experience/raw形成後の失敗、projection/Bias形成時の例外で、公開state全体が変更されない。
- Bias空き2件に対する4関係の受付を全件拒否。部分BiasやExperienceだけを残さない。
- 4threadから同eventを8回要求しても、受付1件・Bias4件だけを保存する。

これは同一Python process内の保証。プロセス再起動・永続化・分散トランザクションの保証ではない。
runは構築時のscope。旧event schemaにWorld run認証を追加したわけではない。

## 二軸の保存結果

既存Python event fixtureと明示outcome facts（NORMAL報酬、light injury）で、独立instanceごとに比較した。

| sensitivity / threshold | 保存される関係 | reward / injury magnitude |
| --- | --- | --- |
| 1 / 1 | acquisition, return | 0 / 0（Biasなし、projectionに抑制理由） |
| 1 / 3 | acquisition, return | 0 / 0 |
| 3 / 1 | acquisition, return, injury, reward_value | 2 / 1 |
| 3 / 3 | acquisition, return, injury | 0 / 1 |

四条件のraw記録は同一。中立(3,0)では旧raw Bias経路の関係値と一致するが、BiasのID/schemaは異なる。
個体A/B、異なるrunの材料は分離される。Aのprofile作成後にBを受付してもAのprofileは変わらない。

## Sleepへの受渡し

`compile_neural_sleep_profile(materials)`は、保存projectionから期待されるBias集合を再構成し、
完全一致を確認する。別run/agent、旧raw/preview schema、改変、重複、材料の欠落を拒否する。
これは整合性検査であり、第三者による材料の真正性を認証する署名ではない。

1Experienceにつき1profile。4関係を4経験の支持として数えない。
関係ごとの神経出典と、抑制された関係を含むprojection summaryを出力する。

- `profiles_available`: 非zeroの関係profileがある。
- `no_experience`: その個体の受付がまだない。
- `all_relations_filtered`: raw非zeroがあるが、保存Biasは0件。
- `no_nonzero_relations`: raw自体が全zero。

現行raw生成器はacquisition=3を必ず持つので、全抑制/全zeroは通常eventから自然発生しない。
この2状態はraw形成器の有限dimension出力を代替した**合成試験**で確認した。
空Biasでもprojection・受付台帳を残すことを検証するためであり、実Worldの事例ではない。

## 予算

既定は個体16、受付/Experience/raw/projection各128、Bias256。eviction・永続化はない。
`capacities`引数で試験用に小さくできるが、上限拡大・未知key・bool・0は拒否する。
実際に128event/256Biasへ到達し、129件目を拒否、既存eventの再送は成功した。
各段階の個別容量は縮小設定による直前/到達/超過でも検査した。

Sleepは個体ごと最大32Bias。8event×4関係=32件を全て受け渡す。
次に合成1関係を追加した33件目では、切り捨てず明示拒否し、保存stateを変更しない。

## 受入対応

`tests/test_neural_outcome.py`: **18テストPASS**。

| ID | 結果 | 主な検査 |
| --- | --- | --- |
| N3-01 | PASS | existing_pipeline_and_actions_unchanged。旧raw経路・Sleep・canonical一致 |
| N3-02 | PASS | four_corners_stored_and_raw_unmodified |
| N3-03 | PASS | neutral_matches_raw_bias_values_but_not_schema |
| N3-04 | PASS | exact_replay_at_capacity_and_conflict / concurrent_duplicates_commit_once |
| N3-05 | PASS | fixed_configuration_and_unassigned_agent / agents_and_runs_are_isolated |
| N3-06 | PASS | each_store_capacity_has_no_partial_commit / default_128_events_and_256_biases_boundary / failure_in_each_staged_phase_keeps_published_state / insufficient_room_for_all_four_biases_rejects_entire_event |
| N3-07 | PASS | no_experience_filtered_and_zero_are_distinct_synthetic |
| N3-08 | PASS | sleep_budget_32_and_33 / sleep_rejects_mixed_schemas_contexts_omissions_and_tampering |
| N3-09 | PASS | old_sleep_rejects_new_schema_and_no_t1_entry / existing_pipeline_and_actions_unchanged |
| N3-10 | PASS | inputs_and_outputs_are_independent / replay_order_and_profile_grouping / 全体回帰 |

```powershell
python -m unittest discover -s tests -p test_neural_outcome.py -v
python -m unittest discover -s tests -v
```

全体: **440件実行 = 394 PASS + 46件の意図的skip**。
NERV-1/2、旧Outcome/Bias・Luanti学習、OBS-7A/7B/8/8B/9保存記録再生を含む。
ログ: `integrations/luanti/output/nerv3-full-tests.log`。
今回はPython検証。Luanti本体・HTTP実機・ブラウザーは再実行していない。

## 停止境界

神経由来Biasの有限保存とSleep入力profileまでを固定する。
新coordinatorは`consolidate`や`t1_cutover`を公開しない。旧Sleep/Deep Similarityは新schemaを拒否する。
Candidate形成、支持閾値、T1、M_B更新、Goal/Trajectory、実Worldの行動差は未接続。
予測誤差やcanonical F/E/Hを実装した扱いにせず、次の接続は別契約で定める。
