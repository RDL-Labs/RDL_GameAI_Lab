# NERV-1/2 神経感度・知覚勾配 Evidence

状態: **PASS / 有限再生・shadow previewで固定** / 2026-09-26。
実装開始点: `f4934834`。Observation v1は`8616fe7e`のまま。
[契約](../experiment-contracts/NERV_1_2_neural_gradient_projection_contract.md)のN12-01〜10をPythonで検証した。
実Luantiの自律行動差、予測誤差処理、本番Bias接続を実装したという意味ではない。

## 実装範囲

`runtime/neural_gradient.py`に次を追加。既存coordinator・bridge・学習処理へのhookはない。

- `NeuralParameter`: frozen dataclass。個体・parameter ID・版と固定二軸を型/範囲検査。
- `project_perceived_gradient(raw_snapshot, request, parameter)`: 出典付きの純粋な有限projection。
- `preview_neural_bias(perceived)`: 専用schemaの非zero関係preview。通常LocalBiasStoreと異なる権限。
- `replay_neural_gradients(raw_snapshot, parameters, queries)`: parameter最大16、明示組最大64、raw最大128。1回のreplayでは1個体1parameterに固定。

raw storeにrun IDはないため、呼出し側が`{"run_id": ..., "gradients": store.snapshot()}`で包む。
requestの正確なfieldは`run_id / agent_id / source_gradient_id / rule_version`。
runnerのqueryは`{"parameter_id": ..., "request": ...}`。同一個体の別parameter比較は独立した再生呼出しで行う。
run IDは実験側のスコープであり、既存storeがWorld runを認証したという意味ではない。
入力は信頼された受理済みsnapshot。整合性検査とSHA-256 IDは再現性のためであり、外部入力の真正性を認証する署名ではない。

raw本体を変えずに、raw値、perceived値、理由、parameter全内容、Experience/event参照を保存する。
全4関係の順序を正規化する。previewでは出典からprojectionを再計算し、改変・別schemaを拒否。
runnerは全入力を検証してから結果を作り、途中までの成功を返さない。永続store・累積更新はない。

## 二軸の結果

既存OutcomeGradientStoreでNORMAL報酬＋light injuryのrawを形成し、独立したparameter条件で再生した。

| sensitivity | reward threshold | perceived reward_value | perceived injury |
| --- | --- | --- | --- |
| 1 | 1 | 0 | 0 |
| 1 | 3 | 0 | 0 |
| 3 | 1 | 2 | 1 |
| 3 | 3 | 0 | 1 |

HIGH報酬3は四条件とも3。raw zeroは全てzero。
低感度・高閾値でNORMAL報酬を抑制した場合、`sensitivity_filtered`と`reward_below_threshold`の両方を保持する。
報酬閾値は正reward_valueだけに作用。負傷の符号を反転せず、acquisition/returnへ閾値を転用しない。
中立parameter (3,0) のpreviewは既存LocalBiasのrelation/direction/strength/magnitudeと一致する。
ID/schema/権限は異なる。previewは通常Biasへ自動投入されない。

## 受入対応

全て`tests/test_neural_gradient.py`で実行した。15 unittestの内部に複数条件を含む。

| ID | 結果 | 主な試験 |
| --- | --- | --- |
| N12-01 | PASS | four_corners_from_existing_store / output_does_not_alias_inputs |
| N12-02 | PASS | parameter_is_frozen_and_strict / reference_and_rule_rejections / malformed_dimensions_rejected |
| N12-03 | PASS | exhaustive_ordinal_table_synthetic_384_cases。4関係×2方向×4段階×3感度×4閾値 |
| N12-04 | PASS | four_corners_from_existing_store。NORMAL/lightとHIGHの同値 |
| N12-05 | PASS | 384組の正負別作用表、raw保持、符号非反転 |
| N12-06 | PASS | both_reasons_and_zero / empty_preview_is_valid_not_missing_data |
| N12-07 | PASS | preview_neutral_matches_existing_bias_values / existing_actions_learning_sleep_canonical_unchanged |
| N12-08 | PASS | identity_and_order_independence / output_does_not_alias_inputs / preview_rejects_tampering_and_wrong_schema |
| N12-09 | PASS | two_agents_and_parameter_order / runner_limits_and_frozen_assignment / runner_validates_all_before_projecting |
| N12-10 | PASS | 既存LuantiOutcomeCoordinatorへ固定3eventを与え、行動・InteractionHistory・Experience/raw/通常Bias・Sleep結果・canonicalの全snapshot一致 |

A/Bは各自のExperience/event/raw IDを持ち、結果値は同一。別個体のrawを付け替えて使わない。
384組は有限作用表の合成試験である。生成器が通常出さないreward=1、関係と方向の組合せを含み、実Worldの結果ではない。
四隅試験もPython fixtureから既存storeへ形成した結果であり、実Luantiを新たに実行したものではない。

## 検証記録と停止境界

```powershell
python -m unittest discover -s tests -p test_neural_gradient.py -v
python -m unittest discover -s tests -v
```

- NERV-1/2: **15 PASS**、合成境界384組を含む。
- 全体: **422件実行 = 376 PASS + 46件の意図的skip**。
- 既存Outcome/Bias、Luanti学習、OBS-7A/7B/8/8B/9の保存済み記録再生もPASS。
- 実Luanti・HTTP実機・ブラウザーは今回再実行していない。World/adapterへの接続変更はない。

error_sensitivityは小さい結果段階を残す局所規則であり、予測値やcanonical Eを入力していない。
reward_thresholdはtheta_effではない。新しいF/E/H、M_B更新、Goal/Trajectory差は未実装。
NERV-1/2とshadow previewをこの範囲で固定し、NERV-3の本番接続は別契約にする。
