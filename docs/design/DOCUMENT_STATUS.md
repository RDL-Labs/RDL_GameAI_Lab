# Design Document Status

確認日: 2026-09-25。基準: GameAI `a7a53e7`、Core `3270982`、C1 authority同期。
これは棚卸し記録であり、実装成熟度の正本は[canonical roadmap](../../notes/experiment-roadmap.md)。

| 文書 | 整理前の分類 | 今回の扱い / 責務 |
|---|---|---|
| [全体設計地図](RDL_GameAI_全体設計地図.md) | partially stale / duplicate details | 4軸と正本リンク。詳細は各責務文書へ委譲 |
| [Profile](RDL_GameAI_NPC_レイヤリング_Profile.md) | partially stale | 名称・目的・時間スケールをNeural Dynamicsへ同期 |
| [Layer計画](RDL_GameAI_NPC_レイヤー別設計計画.md) | partially stale / duplicate details | 所有・更新・保持・比較。上流v0.3とローカル成熟度修正を統合 |
| [感情・履歴](RDL_GameAI_感情・履歴・関係拘束モデル.md) | partially stale | 派生感度・表現・履歴種別の分離 |
| [神経](RDL_GameAI_神経パラメーター設計図.md) | current design / status unclear | 操作的ラベル・DNA μ/σ・動的状態・派生感度。design-only |
| [Neural Individuality / Exploration Future Roadmap](RDL_GameAI_Neural_Individuality_Exploration_Future_Roadmap.md) | NERV-0 future roadmap / contract only | 少数の神経感度差から個体差・探索性を創発させる将来順序。NERV-1..9はDEFERRED / POST-NEURAL、現行runtime非変更 |
| [睡眠](RDL_GameAI_睡眠システム設計.md) | minimal life action + S4 shadow operational | bounded安全場所でのSleep回復と、明示cycleによるS1-S3 shadow consolidation縦断を実装。行動・canonical権限なし |
| [Concept](RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md) | current design | 体験の核。schema・Phaseの正本ではない |
| [生活機能順](RDL_GameAI_実装手順予定.md) | current plan / navigation incomplete | 生活Phaseと横断系、canonical成熟度の分離 |
| [コード抽象度・道具的関数階層](RDL_GameAI_コード抽象度・道具的関数階層_案.md) | current architecture draft v0.1 | I0 PrimitiveからI6 Adapterまでのコード責務、依存方向、pure function境界。Core Tier・NPC Layer・Feature Phaseとは別軸 |
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
| [Rescue Safe-Place Delivery contract](../experiment-contracts/RESCUE_safe_delivery_contract.md) | Phase 5D finite delivery slice operational | attachment、carried movement、fixed safe target、delivery provenance、COMPLETEまで。recoveryは未実装 |
| [Rescue Staged Recovery contract](../experiment-contracts/RESCUE_staged_recovery_contract.md) | Phase 5E finite recovery slice operational | safe-place限定の4段階BodyState更新。旧Safety trajectoryをreleaseし、現在関係を再評価 |
| [Multi-Agent Rescue reference evidence](../experiment-evidence/RESCUE_multi_agent_reference_evidence.md) | Phase 5F reference vertical operational | B行動不能→A発見→一度だけ救助→搬送→段階回復。recovering conditionは再救助対象外 |
| [Sleep / Fast-Deep Experience Loop実装計画](RDL_GameAI_Sleep_FastDeep循環実装計画.md) | completed foundation plan v0.1 | S1-S4、F1、F2完了。day 1 ExperienceからSleep candidate、day 2再発見まで成立。C1同期済み、次はC2 |
| [Runtime / p5 / Godot実装ロードマップ](RDL_GameAI_Runtime_p5_Godot_実装ロードマップ.md) | active cross-surface roadmap v0.1 | Runtimeを意味論、p5をread-only観測、Godotを統合試験へ固定。F1/F2、Core同期、T1、Dynamic M_B、Godot再統合の順序と停止条件 |
| [Luanti Integration Roadmap](RDL_GameAI_Luanti_Integration_World_Backend_Transition_Roadmap.md) | active infrastructure roadmap | L0-L9とRW1-RW2完了。Luantiを主World統合面、Godotをregression fixtureとして保持。L10 M_B-informed behaviorは保留 |
| [Observation System Integration Plan](RDL_GameAI_Observation_System_Integration_Plan.md) | active implementation plan v0.2 | OBS-0〜4完了。個体別profile、隔離store、近景、有限遠景、最小聴覚を導入。次はOBS-5〜6 read-only表示・統合回帰、感覚融合・行動接続・嗅覚は保留 |
| [OBS Common Boundary contract](../experiment-contracts/OBS_common_boundary_contract.md) | OBS-0/1 operational reference | extensionをRuntime入口でlegacy packetから分離。不正extension時もlegacy処理を継続し、run/epoch照合・sequence/time逆行拒否・有限store・GET-only snapshotへ隔離。既存意味論・action権限なし |
| [OBS Local Profile Compatibility contract](../experiment-contracts/OBS_local_profile_compatibility_contract.md) | OBS-2 operational reference | 既定radius 12でRW2互換、同距離10をradius 12/8で個体別観測差。reach・行動則・canonical権限は不変 |
| [OBS Distant Observation contract](../experiment-contracts/OBS_distant_observation_contract.md) | OBS-3 operational reference | observer-local方向区間と粗い見え方だけを有限取得。実voxel遮蔽、向き変更、未ロード非透明、exact distance/座標/World ID非漏洩を固定。行動非介入 |
| [OBS Audition Observation contract](../experiment-contracts/OBS_audition_observation_contract.md) | OBS-4 operational reference | direct band energy、壁減衰、同一cell混合、個体gain差、短期buffer overflowのPARTIAL記録を実Luantiで固定。音源同定・意味・action権限なし |
| [Luanti L0-L2 Bridge contract](../experiment-contracts/LUANTI_L0_L2_bridge_contract.md) | L0-L2 operational reference | Luanti 5.17実機でfinite observation→既存Runtime→approach/pickup→World consequence→next observationを固定 |
| [Luanti L3 Ordinary Food contract](../experiment-contracts/LUANTI_L3_ordinary_food_contract.md) | L3 operational reference | 既存BaseFoodLifePolicyでLuanti approach→pickup→Base帰還→deposit→causal result admissionを固定。exact stock非漏洩 |
| [Luanti L4 Risky Tasty Food contract](../experiment-contracts/LUANTI_L4_risky_tasty_food_contract.md) | L4 operational World reference | source付き発話と有限territory relationを観測し、Luanti-owned warning→chase→attack→medium injury→forced retreatを固定。学習・danger belief非導入 |
| [Luanti L5 Outcome Learning contract](../experiment-contracts/LUANTI_L5_outcome_learning_contract.md) | L5 operational local-learning reference | 実Luanti attack fact→Territory Experience→Outcome Gradient→3 Local Biasを固定。action・canonical非介入 |
| [Luanti L6 Sleep / Deep Candidate contract](../experiment-contracts/LUANTI_L6_sleep_deep_candidate_contract.md) | L6 operational shadow-learning reference | 3実outcome→Local Bias Profile→Deep Similarity→support-3 shadow Candidateを固定。自動昇格なし |
| [Luanti L7 Dynamic M_B Cycle contract](../experiment-contracts/LUANTI_L7_dynamic_mb_cycle_contract.md) | L7 operational dynamic-model reference | Luanti候補と独立canonical ruptureをT1-Aで合流し、明示選別→inactive M_B'→cutover→fresh REENTEREDを固定。action authorityなし |
| [Luanti L8 Multi-Agent Separation contract](../experiment-contracts/LUANTI_L8_multi_agent_separation_contract.md) | L8 Runtime/adapter separation reference | agent/Sleep/candidate/assessmentを明示参照し、A/BのExperience・candidate・model・archive・M_delta非混線を固定。実World同時生活は未主張 |
| [Luanti L9 p5 Read-Only Trace contract](../experiment-contracts/LUANTI_L9_p5_read_only_trace_contract.md) | L9 operational observation reference | agent別Experience→Bias→Sleep→Candidate→T1→modelをGET-only表示。欠落段階・未公開World位置を補完しない |
| [Luanti RW1 Multi-Agent World contract](../experiment-contracts/LUANTI_RW1_multi_agent_world_contract.md) | RW1 operational rich-World reference | 実Luanti同一WorldでA/Bが相互をbounded観測し、別Foodへ独立approach/pickup。social意味・learning・M_B actionなし |
| [Luanti RW2 Multi-Agent Food Life contract](../experiment-contracts/LUANTI_RW2_multi_agent_food_life_contract.md) | RW2 operational rich-World reference | 専用Food/BaseでA/Bが独立pickup、return、deposit、causal resultまで完了。共有資源・Sleep・M_B actionなし |
| [Core 3270982 Authority Sync contract](../experiment-contracts/CORE_3270982_authority_sync_contract.md) | C1 semantic synchronization complete | SILN・履歴、xi、dynamic theta_eff、H、M_delta、T1のGameAI authority境界。Runtime権限追加なし |
| [Canonical Review Path Projection contract](../experiment-contracts/CANONICAL_review_path_projection_contract.md) | C2 operational diagnostic projection | assessment IDごとにRIB_B/F/RIB_B'/F'/E/review/Hを追跡。candidate系を除外し、p5 GET-only表示 |
| [Canonical Theta Effective contract](../experiment-contracts/CANONICAL_theta_effective_contract.md) | C3 operational diagnostic evaluation | reviewed Hと独立provenanceのtheta_effを比較。M_delta遷移・T1・action authorityなし |
| [Canonical M_delta Transition contract](../experiment-contracts/CANONICAL_M_delta_transition_contract.md) | C4 operational phase transition | explicit review時だけnormal/M_deltaを遷移。T1・M_B'・re-entry・action authorityなし |
| [C4後 Multi-Agent / Territory Beast検証計画](RDL_GameAI_C4後_Multi-Agent_Territory_Beast検証計画.md) | Temporary validation complete | R1-R7完了。3/5/10 agents、Territory Beast、combined Experience、C1-C4回帰を固定 |
| [Territory Beast World contract](../experiment-contracts/TERRITORY_BEAST_world_contract.md) | R4-R5 operational fixture | danger labelなしのoutside/warning/chase/attack事実経路。canonical非介入 |
| [Territory Beast Experience contract](../experiment-contracts/TERRITORY_BEAST_experience_contract.md) | R6 operational local Experience | direct/observer provenanceを分離。candidate・H・theta・M_deltaへの自動接続なし |
| [T1 Material Expansion contract](../experiment-contracts/T1_material_expansion_contract.md) | T1-A operational | active M_deltaからcanonical/local材料をUNINSPECTEDで凍結。選別・再構成なし |
| [T1 Material Selection contract](../experiment-contracts/T1_material_selection_contract.md) | T1-B operational | 全材料をRETAIN/REJECT/DEFERへ明示選別。RETAINは採用ではなく再構成なし |
| [T1 Reconstruction contract](../experiment-contracts/T1_reconstruction_contract.md) | T1-C operational | retained parent/candidateからinactive M_B'を新規生成。cutover・re-entry・action authorityなし |
| [Dynamic M_B Inactive Cycle contract](../experiment-contracts/DYNAMIC_MB_inactive_cycle_contract.md) | DMB-A operational evidence | Experience/candidateとcanonical ruptureをT1-Aでのみ合流しinactive M_B'まで追跡 |
| [Dynamic M_B Cutover / Re-entry contract](../experiment-contracts/DYNAMIC_MB_cutover_reentry_contract.md) | DMB-B operational | parent archive、M_B' activation、fresh comparison window、M_delta REENTERED。game action authorityなし |
| [Dynamic M_B Multi-Agent Regression contract](../experiment-contracts/DYNAMIC_MB_multi_agent_regression_contract.md) | DMB-C complete | 2個体のcandidate/model/archive/M_delta/fresh windowを独立検証。local action不変 |
| [G1 Godot Dynamic M_B Reintegration contract](../experiment-contracts/G1_Godot_dynamic_mb_reintegration_contract.md) | G1 operational | Godot所有の身体・空間・実行動からDMB cutover、REENTERED、fresh比較までを再統合。local action不変 |
| [G2-A Long-Life Dynamic M_B contract](../experiment-contracts/G2A_long_life_dynamic_mb_contract.md) | G2-A operational | 同一Godot Worldでday 1 Food/Safety、Sleep、DMB cutover、day 2 cueなし自律まで接続。一般arbitrationなし |
| [G2-B Multi-Agent Long-Life contract](../experiment-contracts/G2B_multi_agent_long_life_contract.md) | G2-B operational | 同一World/RuntimeでA/Bが別candidate・model・archive・M_delta・habitを保ち、翌日のcueなし自律まで完走 |
| [Risky Tasty Food Reference contract](../experiment-contracts/RISKY_TASTY_FOOD_reference_contract.md) | RTF-1..4 operational reference | ordinary/tasty Food、source付き神像statement、既存Territory warning/chase/attack/injury、Food関係付きExperienceを分離維持 |
| [Outcome Gradient / Local Bias contract](../experiment-contracts/OUTCOME_GRADIENT_local_bias_contract.md) | OGB-1..5 operational reference | success/failure/mixedをrelation別gradientとagent-owned biasへ形成。相殺なし、Sleep材料のみ、canonical/action非介入 |
| [Local Bias Sleep Relation Profile contract](../experiment-contracts/LOCAL_BIAS_sleep_profile_contract.md) | OGB-6 operational reference | agent-owned Biasを専用Sleep Profileへ純粋変換。mixed/provenance保持、Similarity/Candidate/action非生成 |
| [Local Bias Deep Similarity contract](../experiment-contracts/LOCAL_BIAS_deep_similarity_contract.md) | OGB-7/8 operational reference | 同一agentの3〜6 Profileを比較しshadow candidateを最大1件形成。mixed/conflict/provenance保持、T1/M_B/action非昇格 |
| [Local Bias T1 Candidate Projection contract](../experiment-contracts/LOCAL_BIAS_t1_projection_contract.md) | OGB-9 operational reference | mixed candidateをrelation別T1-ready材料へ投影。明示T1-A投入後もUNINSPECTED、自動採用/action化なし |
| [Finite Sleep Experience Window contract](../experiment-contracts/SLEEP_experience_window_contract.md) | S1 operational reference | 同一NPC・同一sleep cycleのaccepted raw Experienceを最大6件で固定。不足状態とsource追跡を明示。Profile / candidate / canonical authorityは未実装 |
| [Sleep Relation Constraint Profile contract](../experiment-contracts/SLEEP_relation_profile_contract.md) | S2 operational reference | I1有限relation構築とI2 pure compiler。actor / target / context / action / outcomeをsource付きで派生し、candidate・canonical authorityへ非介入 |
| [Sleep Deep Similarity Shadow contract](../experiment-contracts/SLEEP_deep_similarity_shadow_contract.md) | S3 operational reference | I1 alignment、I2 pure Deep function、I3 immutable store。最大6 Profile / 15 pair、one cluster / candidate、coverage・conflict・unresolved非混同、非介入 |
| [Sleep Consolidation Vertical contract](../experiment-contracts/SLEEP_consolidation_vertical_contract.md) | S4 opt-in operational reference | cycle開始時に昼Experienceを固定し、実Sleep resultからS1-S3 shadow candidateへ接続。action / canonical非介入 |
| [Sleep Consolidation S4 Evidence](../experiment-evidence/SLEEP_consolidation_reference_evidence.md) | S4 real Godot/HTTP evidence | transit Experienceを固定window外へ保ち、3件の昼Experienceだけをcandidate sourceとして追跡 |
| [Activity Fast Retrieval contract](../experiment-contracts/FAST_activity_retrieval_contract.md) | F1 opt-in operational reference | source-aware L0 signature overlap、有限L1、top-3、raw/candidate分離、p5 read-only観測、action非介入 |
| [Fast / Deep One-Cycle Evidence](../experiment-evidence/FAST_DEEP_one_cycle_evidence.md) | F2 Runtime/HTTP evidence complete | day 1の3 Experienceから形成したcandidateをday 2 Fastで再発見。candidate ID、Sleep cycle、全source IDsを追跡 |
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
- 動的神経モデル、会話、DNA、canonical game action authorityは未実装。Sleep S1-S4、finite theta_eff、M_Δ、T1-A-C、canonical evaluator cutover / re-entryは参照実装済み。

## 検証

- README、docs、notesのMarkdown 29件についてローカルリンクとコードフェンスを確認。エラーなし。
- Godot 4.7.2の実HTTP連携5件を含む既存70テスト成功、skipなし。
- runtime / godot / experimentsの追跡ファイルは差分なし。test変更は層間分離acceptanceの意味を明示するdocstringのみで、assertionと挙動は不変。
- 未解消競合なし、git diff --check成功。新規commit・pushは実施していない。
