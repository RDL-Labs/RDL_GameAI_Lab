# Design Document Status

確認日: 2026-09-17。基準: upstream `19ce133` と前回の未commit文書同期・層間分離検証。
これは棚卸し記録であり、実装成熟度の正本は[canonical roadmap](../../notes/experiment-roadmap.md)。

| 文書 | 整理前の分類 | 今回の扱い / 責務 |
|---|---|---|
| [全体設計地図](RDL_GameAI_全体設計地図.md) | partially stale / duplicate details | 4軸と正本リンク。詳細は各責務文書へ委譲 |
| [Profile](RDL_GameAI_NPC_レイヤリング_Profile.md) | partially stale | 名称・目的・時間スケールをNeural Dynamicsへ同期 |
| [Layer計画](RDL_GameAI_NPC_レイヤー別設計計画.md) | partially stale / duplicate details | 所有・更新・保持・比較。上流v0.3とローカル成熟度修正を統合 |
| [感情・履歴](RDL_GameAI_感情・履歴・関係拘束モデル.md) | partially stale | 派生感度・表現・履歴種別の分離 |
| [神経](RDL_GameAI_神経パラメーター設計図.md) | current design / status unclear | 操作的ラベル・DNA μ/σ・動的状態・派生感度。design-only |
| [睡眠](RDL_GameAI_睡眠システム設計.md) | minimal life action operational / consolidation design-only | bounded安全場所でのSleep回復は実装済み。横断Consolidationは未実装 |
| [Concept](RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md) | current design | 体験の核。schema・Phaseの正本ではない |
| [生活機能順](RDL_GameAI_実装手順予定.md) | current plan / navigation incomplete | 生活Phaseと横断系、canonical成熟度の分離 |
| [Base–Food循環完成計画](RDL_GameAI_Codex_BaseFood循環完成計画.md) | completed reference plan v0.3 | 神の像の粗いcueからNPC自身の予測・Goal・Trajectory・経験・自律化へ進むBase–Food参照loop |
| [Base–Food assisted contract](../experiment-contracts/BASE_FOOD_assisted_loop_contract.md) | reference baseline complete | Phase 1-8、interrupt三系統、Novelty復帰、両端preset比較まで。Evidence固定済み |
| [Base–Food completion evidence](../experiment-evidence/BASE_FOOD_reference_loop_evidence.md) | current evidence | 実Godot/HTTP 111 tests、Stage 1-4、FoodNeed shadow維持判断、Rest開始境界 |
| [ρ活用指南](RDL_GameAI_ρ活用指南.md) | operational reference / further expansion deferred | domain別Observation Adapterの利用基準、禁止する近道、v0.x停止境界 |
| [ρ v0.x Evidence](../experiment-evidence/RHO_v0_reference_evidence.md) | closed operational reference | Food非介入、Rest横断再利用、候補記述→固定selector→target差、再開条件 |
| [ρ observation contract](../experiment-contracts/RHO_observation_resolution_contract.md) | operational reference | LOW/MID/HIGH、NPC/domain別選択、packet sidecar、exact値非漏洩、default/canonical非介入 |
| [ρ Rest observation contract](../experiment-contracts/RHO_rest_observation_contract.md) | minimal diagnostic projection operational | Rest LOW/MID/HIGH、有限trend、可視休息文脈、RestNeed・sleep行動・consolidation非介入 |
| [Minimal Rest loop contract](../experiment-contracts/REST_minimal_loop_contract.md) | opt-in isolated loop operational | Godot所有RestNeed、bounded rest point、approach、short rest、回復。Sleepは別契約、Consolidation未実装 |
| [Minimal Sleep life-action contract](../experiment-contracts/SLEEP_life_action_contract.md) | opt-in bounded action operational | RestNeed + 明示window + safe place、Sleep回復。World Time / Consolidation未実装 |
| [Minimal ActiveEnergy loop contract](../experiment-contracts/ACTIVE_ENERGY_minimal_loop_contract.md) | opt-in body loop operational | 実移動で消費、short restで小回復、Sleepで大回復。EnergyReserve・行動権限は未実装 |
| [Minimal EnergyReserve loop contract](../experiment-contracts/ENERGY_RESERVE_minimal_loop_contract.md) | opt-in body reserve operational | movement・short restでは不変、Sleepで有限回復。移送・代謝・行動権限は未実装 |
| [ActiveEnergyCapacity contract](../experiment-contracts/ACTIVE_ENERGY_CAPACITY_contract.md) | opt-in finite body constraint operational | 個体別有限上限、即時clamp、回復上限、不正更新atomic rejection。行動権限なし |
| [Phase 3 Energy Evidence](../experiment-evidence/ENERGY_phase3_reference_evidence.md) | closed operational reference | ActiveEnergy・EnergyReserve・Capacityの実Godot結果、分離境界、再開条件を固定 |
| [Minimal Safety flee contract](../experiment-contracts/SAFETY_minimal_flee_contract.md) | opt-in bounded safe-target trajectory operational | static danger zone、固定safe target、圏外後も継続、Plaza到達で完了。Threat・負傷は未実装 |
| [Safety Target Selection contract](../experiment-contracts/SAFETY_target_selection_contract.md) | finite multi-candidate selection operational | safe優先、同安全度で有限距離比較、一度だけ選択。Trajectory・World truth責務を分離 |
| [Safety Danger Selection contract](../experiment-contracts/SAFETY_danger_selection_contract.md) | finite dominant-danger selection operational | high/medium/low比較、同severity時ID順。safe target・行動・負傷の権限なし |
| [Safety Moving Threat contract](../experiment-contracts/SAFETY_moving_threat_contract.md) | opt-in moving fixture operational | Godot所有位置を有限更新し、bounded exposureから同じ固定safe targetへ逃走。predator・追跡予測・負傷ではない |
| [Workbench Visualization contract](../experiment-contracts/WORKBENCH_visualization_contract.md) | V1-V3 debug projection operational | Entity図形、観測円、固定target線、danger領域、moving threat。表示はWorld・decisionへ非介入、Inspector V4は保留 |
| [Base-Food Result Causality contract](../experiment-contracts/BASE_FOOD_result_causality_contract.md) | continuous-life Phase A operational | exact replay副作用なし。successを同agentの登録済みBase deposit decision・cue・goalへ拘束 |
| [Base-Food Three-Cycle Autonomy contract](../experiment-contracts/BASE_FOOD_three_cycle_autonomy_contract.md) | continuous-life Phase C operational | 同一World/Runtime/NPCで実deposit成功2周、cueなし自律3周。事前success投入なし |
| [Multi-Agent Simulation Loop contract](../experiment-contracts/MULTI_AGENT_simulation_loop_contract.md) | continuous-life Phase D operational | selected inspectorと実行対象を分離。A/B逐次observe/decide/resolve、生活modeではmock wandering停止 |
| [Food-Safety Continuous-Life contract](../experiment-contracts/FOOD_SAFETY_continuous_life_contract.md) | continuous-life Phase E operational | Food保持帰還中に危険、Food保留、Safety完了、現関係再検査、resume/deposit。一般Need arbitrationではない |
| [Continuous Life Reference Evidence](../experiment-evidence/CONTINUOUS_LIFE_reference_evidence.md) | continuous-life Phase F operational | 別Shelter退避を含む成功、通常成功、cueなし自律完走を同一NPC/Runtime/Worldで固定。優先縦断はPhase G CI対象 |
| [Food-Rest Continuous-Life contract](../experiment-contracts/FOOD_REST_continuous_life_contract.md) | first finite integration slice operational | Food保持中の高RestNeed、Food保留、別Rest Hutでshort rest、現在packet再評価、Plaza帰還/deposit。一般Need arbitrationではない |
| [Safety Failure / Incapacitation contract](../experiment-contracts/SAFETY_incapacitation_contract.md) | Phase 5A finite failure slice operational | failed flee 3回、Godot-owned severe injury / incapacitated、bounded body snapshotによるaction拘束。Rescue / Recoveryは未実装 |
| [Rescue Bounded Discovery contract](../experiment-contracts/RESCUE_bounded_discovery_contract.md) | Phase 5B finite observation slice operational | 範囲内の別NPCへincapacitated conditionだけを投影。Rescue Goal / delivery / recoveryは未実装 |
| [Rescue Goal / Trajectory contract](../experiment-contracts/RESCUE_goal_trajectory_contract.md) | Phase 5C finite approach slice operational | target固定、approach、READY_TO_RESCUEまで。carry / delivery / recoveryは未実装 |
| [Rest Goal / Trajectory contract](../experiment-contracts/REST_trajectory_contract.md) | opt-in trajectory operational | 固定target、generic保留、同一target復帰、完了、構造的release。候補比較は独立policy、Need arbitration未実装 |
| [Rest Target Selection contract](../experiment-contracts/REST_target_selection_contract.md) | finite multi-candidate selection operational | safe優先、同安全度で有限距離band比較、一度だけ選択、ρ・Trajectory責務分離 |
| [ρ Rest Candidate Description contract](../experiment-contracts/RHO_rest_candidate_description_contract.md) | double-opt-in causal experiment operational | ρ→候補記述、固定selector→target、Trajectory固定。LOW/HIGH実Godot比較 |
| [FoodNeed M_B Admission計画](RDL_GameAI_FoodNeed_M_B_Admission実装計画.md) | PR 1-3 operational | opt-in acquisition、immutable relation、shadow F/F'/E、default-off loopback bridge。global sidecar接続は未実装 |
| [会話](RDL_GameAI_簡易会話からプレイヤー介入まで.md) | current design / phase ambiguous | intent・referent・DialogueTurn・語彙。Communication Stepは生活Phaseと別 |
| [Player](RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md) | current draft | 外部語彙・情報入力と有限な自動生活cue。直接操作・Truth権限なし |
| [設計手法](RDL_GameAI_設計手法.md) | partially stale | 設計規律・有限検証・semantic fallibility / structural integrity |
| [canonical roadmap](../../notes/experiment-roadmap.md) | partially stale | Maturityごとのimplemented slice / remaining boundary |
| [README](../../README.md) | duplicate / partially stale | 入口・実行案内。詳細は正本へ |
| [旧村設計](RDLどうぶつの森風村シミュレーター設計文書.md) | legacy / concept overlap | historical referenceとしてsource-mine対応表を保持 |

全文統合・削除対象はなし。地図・README・Layer計画内の重複詳細のみ正本へ委譲する。
旧村設計は既存参照と採掘元の対応表を残すため移動せず、現行Concept / Playerより優先しないと明示する。

## 今回の変更境界

### Rescue bounded discovery（2026-09-19）

- Phase 5B: 観測範囲内の別NPCだけが `condition = incapacitated` を受け取る有限観測slice。
- exact injury、movement capability、danger exposure履歴はobserver packetへ渡さない。
- global通知、Rescue Goal、搬送、回復、旧Safety trajectory処理はdeferred。
- 契約: `docs/experiment-contracts/RESCUE_bounded_discovery_contract.md`。

### M_B参加意味論（2026-09-17）

- Layer docs: current。5 Layerは `M_B` の外部状態系や5分割ではなく、関係の出所・更新速度・保持時間・provenanceを整理するViewへ改訂。
- Food contract: FoodNeedはsemantic `M_B` participantとしてintended。現行canonical count-sidecarへのadmissionはdeferred。
- Cross-layer contract: 現行runtimeのfrozen `M_B` をlocal変更が黙示mutationしないことの分離契約。Body / Neural / History由来relationの永久除外は主張しない。
- Runtime authority、graph mutation、θ / M_Δ / T1 cutoverは変更なし。

### Assisted-to-autonomous Base–Food方針（2026-09-18）

- 神の像はWorldの精密Food状態を粗い生活cueへ圧縮するが、NPCへaction commandを与えない。
- NPCはcueを有限観測として受け、自身のM_Bで解釈・短期予測し、Goal / Trajectory / Commitment / Phaseを形成する。
- 毎朝cue → Base–Food完遂 → 従う/無視の結果 → 経験hook → cueなしの自律起動まで検証済み。
- generic / Threat / Novelty割り込み、復帰、固定個体差、extreme tuning比較まで検証済み。
- FoodNeed shadow PR4はEvidence review後もshadow維持。次の再検討点は非Food生活loopの成立後。
- sharing / spoilage / individual IDs / hunting / social / multi-resource実装は今回含めない。

変更対象は `README.md`、`docs/design/`、`docs/experiment-contracts/`、`notes/experiment-roadmap.md` と層間分離テストの説明文。runtime / Godot挙動、Evidence、semantic referenceは変更しない。
DNA・動的神経状態・睡眠・会話・生活機能の詳細は設計候補であり、文書整合によって実装済みに昇格しない。

## 残す表記と未実装範囲

- Layer計画の改訂履歴にある旧Layer名は名称変更の記録として保持する。
- 既存Sensitivity契約の旧Layer名とExperience契約の「Next 2」は過去の有限sliceの参照表記として残す。今回は契約の再承認・内容変更を行わず、現行配置と成熟度は設計地図・canonical roadmapで示す。
- 動的神経モデル、睡眠整理、会話、DNA、θ / M_Δ / T1は未実装。これは文書の同期漏れではなく、実装境界として明記したもの。

## 検証

- README、docs、notesのMarkdown 29件についてローカルリンクとコードフェンスを確認。エラーなし。
- Godot 4.7.2の実HTTP連携5件を含む既存70テスト成功、skipなし。
- runtime / godot / experimentsの追跡ファイルは差分なし。test変更は層間分離acceptanceの意味を明示するdocstringのみで、assertionと挙動は不変。
- 未解消競合なし、git diff --check成功。新規commit・pushは実施していない。
