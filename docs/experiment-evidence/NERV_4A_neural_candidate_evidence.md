# NERV-4A 神経由来の有限Candidate Evidence

状態: **PASS / N4A-01〜10完了 / 局所Candidateまで固定** / 2026-09-26。
実装開始点: `d153521e`。[契約](../experiment-contracts/NERV_4A_neural_candidate_contract.md)に対応。

## 実装と境界

`runtime/neural_candidate.py`の`build_neural_candidate(materials, request)`を追加した。
NERV-3の材料全体を既存`compile_neural_sleep_profile`で再検査してから、明示指定した3〜6 Experienceを比較する。
未選択の改変材料も拒否する。全指定経験で同じ非zero signatureを持つ関係だけを、最大1件の
`nerv-relation-candidate-v1`へまとめる。最大15組・60関係判定。選択7件、重複指定、前段32 Bias上限超過は切り詰めず拒否する。

`insufficient_experiences / not_comparable / no_candidate / candidate_formed`を区別する。
抑制は反証にせず、raw zero、強度差、方向差と分け、同時に成立する複数理由も保持する。
3経験で一致して4件目だけ抑制された関係は共通集合から外す。3件の支持と4件目の抑制理由は診断に残す。
全抑制の経験も選択集合から除かない。

## 神経条件による結果

同じNORMAL reward・light injuryの3経験を、固定parameterごとの別instanceで再生した。

| sensitivity / threshold | Candidateの共通関係 | 各関係の支持 |
| --- | --- | --- |
| 1 / 1 | acquisition, return | 3 Experience |
| 1 / 3 | acquisition, return | 3 Experience |
| 3 / 1 | acquisition, return, injury, reward_value | 3 Experience |
| 3 / 3 | acquisition, return, injury | 3 Experience |

HIGH reward・injury noneでは四隅ともacquisition, return, reward_valueとなる。
parameter差が必ずCandidate差を作るという主張ではない。
同じeventの再送・同条件の再評価で結果と支持数は変わらない。
別sleep_cycle/tickでは識別IDが変わるが、支持数は同じ3経験のままである。
支持数を永続蓄積する処理はない。

## 出典と非介入

結果の`selected_projections`はrawを含む選択元全内容を保持する。
`pair_results`は全組の診断、`relation_results`はsignature別支持群と未支持理由を保持する。
Candidateには固定parameter全内容・規則・run/agent・cycle/tick・Experience/raw/projection/profile/event参照と共通signatureを残す。
`source_bias_ids`は共通関係の根拠Biasのみ。zeroに架空のBias/profile参照を作らない。
選択・材料の順序を入れ替えても結果全体とIDが同じ。出力変更が入力や保存stateへ波及しない。

新Candidateを既存T1投影へ渡すと拒否される。旧Sleep/Deep/T1のschema許可条件は変更していない。
固定3packetで本関数を呼ぶ場合／呼ばない場合を比べ、保存state・既存Action・InteractionHistory・canonical snapshotの一致を確認した。
これはPython固定入力試験であり、実World全行動列の一致を主張しない。

## 受入検査

`tests/test_neural_candidate.py`の16テストがPASS。

| 契約 | 検査内容 |
| --- | --- |
| N4A-01 | 四隅parameterの共通関係差、HIGHで同じ結果 |
| N4A-02 | 6経験・15組・60判定、再送・再Sleepで支持不増 |
| N4A-03 | raw zero・神経抑制・強度差・符号差と複数理由 |
| N4A-04 | 0〜2経験、文脈差、全zero/全抑制、共通関係あり |
| N4A-05 | 不正型・scope・参照、改変・欠落・旧schema、未選択の不正材料も拒否 |
| N4A-06 | 6件の上限、重複を含む7件拒否、前段Bias上限拒否 |
| N4A-07 | 3一致+1抑制を全4件の共通関係にしない |
| N4A-08 | 出典・parameter、順序不変ID、mutable aliasなし |
| N4A-09 | 既存T1投影が新Candidateを拒否 |
| N4A-10 | 保存・行動・canonical不変、全体回帰PASS |

通常例はPythonの既存event形成→NERV-3受付→専用compiler→候補関数を通す。
全raw zero・全抑制・通常生成器が出さない符号/強度境界は、rawのdimensions生成を置換した**合成fixture**である。
神経投影・受付・材料compiler・候補関数自体は置換していない。実環境の経験分布を示す試験ではない。

実行: `python -m unittest discover -s tests -v`

```text
Ran 456 tests
OK (skipped=46)
456件実行 = 410 PASS + 46 intentional skip
```

Luanti・HTTP・ブラウザーは今回再実行していない。変更は独立したPython純粋関数・試験・文書に限定。
観測v1とNERV-1/2/3の既定経路を維持する。
T1への選別、M_B更新、Goal/Trajectory、行動差、長期保持は未接続であり、別契約を要する。
