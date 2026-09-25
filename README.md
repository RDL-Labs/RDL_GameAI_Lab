# RDL Game AI Lab

**強さだけでなく、履歴から理解できる個体差や意外性を持つGameAIを実験する。**

目指す体験は、かわいい生き物が小さな世界で食べ、休み、失敗し、助け合い、回復しながら暮らす生活シミュレーション。現在動くものは、そのための有限な実験Workbenchであり、完成した生活ゲームではありません。

## Start here

1. [全体設計地図](docs/design/RDL_GameAI_全体設計地図.md): 4軸と各文書の正本
2. [Game Concept](docs/design/RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md): 体験・世界観
3. [NPC Layer Plan](docs/design/RDL_GameAI_NPC_レイヤー別設計計画.md): 状態の所有・更新・保持・検証
4. [Canonical Experiment Roadmap](notes/experiment-roadmap.md): 実装成熟度と残る境界
5. [Current Runtime Contract](docs/experiment-contracts/CURRENT_v23_runtime_contract.md): 現行動作の有限契約
6. [Base–Food循環完成計画](docs/design/RDL_GameAI_Codex_BaseFood循環完成計画.md): 完了した参照生活ループ
7. [ρ活用指南](docs/design/RDL_GameAI_ρ活用指南.md): 観測解像度をGameAIへ導入する際の判断基準
8. [コード抽象度・道具的関数階層](docs/design/RDL_GameAI_コード抽象度・道具的関数階層_案.md): I0 PrimitiveからI6 Adapterまでの実装責務と依存方向
9. [p5.js Observation Workbench](gui-p5/README.md): read-only I6 Viewer。Experience→Sleep Window→Profile→CandidateのprovenanceとLive GET endpoint状態を可視化
10. [Runtime / p5 / Godot実装ロードマップ](docs/design/RDL_GameAI_Runtime_p5_Godot_実装ロードマップ.md): F1からDynamic M_B、Godot再統合までの実行面・authority・停止条件

生活機能の追加順は[Game Feature Roadmap](docs/design/RDL_GameAI_実装手順予定.md)、コード内の抽象度と依存方向は[道具的関数階層案](docs/design/RDL_GameAI_コード抽象度・道具的関数階層_案.md)で管理します。

## Four separate axes

| 軸 | 管理するもの |
|---|---|
| A. Canonical RDL maturity | RIB_B / frozen M_B / E / review / H、将来のT1・authority |
| B. NPC internal layers | Generation / DNA、Neural Dynamics、Physical / Body、Experience / Relation History、Realtime / Current Context |
| C. Game feature implementation | Food・Rest・Energy・Safety・Rescue等の生活機能 |
| D. Cross-cutting systems | World Time・Communication・Vocabulary・Player・Sleep Consolidation等 |

canonical maturity != game feature phase。Layer ProfileはCore ontologyでもM_Bの分解定義でもありません。Neural Dynamicsは内部状態の配置先であり、その影響経路は横断系としても検査します。睡眠は第6Layerではなく横断更新イベントです。

各Layerは、現在の有限なagent-side関係・parameterの出所、更新速度、保持時間、provenanceを整理するViewです。owner module / store自体は `M_B` ではありませんが、宣言したBoundaryで明示的に採用された現在関係は `M_B` を構成し得ます。現行canonical runtimeはFoodNeedを含む全parameterをまだoperational admissionしていません。

## Current implementation

- Canonical diagnostics: bounded observation → finite B → RIB_B → frozen M_B → F/F' → E → explicit finite residual review → H / retained H。
- GameAI-local behavior: 有限なapproach結果履歴、任意のhistory retry policy、固定1/3/5 tick profile、Godot所有のmovement_scale、現在観測。
- First game feature: [minimal Food loop](docs/experiment-contracts/FOOD_minimal_loop_contract.md)。FoodNeed → approach → pickup → eat → world消費 / Need低下。
- Current direction: Restの固定target・interrupt復帰に加え、RestNeed + 明示window + safe place → sleep → 回復を実縦断した。Sleep Consolidationは明示cycleのS4 shadowとして実装済みで、World Timeとaction authorityは未実装。
- Operational assisted slice: 粗いcueからBase–Foodを完遂し、follow / ignore結果を分離する。deposit成功を有限経験として保持し、2成功後のみcueなしのlearned relationから同じ一周を自律起動できる。generic保留・再開、Threat profile差、Novelty三応答と復帰、両端の調整用extreme profile比較まで実装済み。
- Reference status: [Base–Food completion evidence](docs/experiment-evidence/BASE_FOOD_reference_loop_evidence.md)と[ρ v0.x evidence](docs/experiment-evidence/RHO_v0_reference_evidence.md)を固定。FoodNeed canonical promotionはshadow維持、ρ追加展開はdeferred。
- Observation resolution: [ρ contract](docs/experiment-contracts/RHO_observation_resolution_contract.md)でFood / RestのLOW / MID / HIGH、版付きprofile、packet sidecar、provenanceを実装。default actionとcanonical pathは非介入。Restの二重opt-in実験のみ候補記述へ接続済み。
- Rest behavior: opt-in隔離modeでGodot所有RestNeedがtick増加し、独立した[有限target selection](docs/experiment-contracts/REST_target_selection_contract.md)が一度だけ候補を選ぶ。[ρ Rest candidate実験](docs/experiment-contracts/RHO_rest_candidate_description_contract.md)はLOW/HIGHで候補記述だけを変え、同じselectorから異なるtargetを得る。Trajectoryはgeneric interrupt後も同じtargetへ復帰する。Food priorityは未接続。
- Sleep behavior: opt-in隔離modeで `RestNeed >= 0.85`、明示sleep window、bounded safe placeが揃った時だけPlazaへapproachしてsleepする。GodotがRestNeedを回復し、`consolidation=not_run`を記録する。
- Energy: opt-in時のみGodotが独立したActiveEnergy / EnergyReserveと個体別ActiveEnergyCapacityを所有する。実移動はActiveEnergyだけを消費、short restはActiveEnergyだけを小回復、Sleepは両方を回復し、ActiveEnergy回復はcapacityで止まる。reserve移送と行動選択への接続はまだ行わない。
- Phase 3 status: [Energy Evidence](docs/experiment-evidence/ENERGY_phase3_reference_evidence.md)で参照実装を閉じた。次の生活境界はSafety / Dangerで、具体的AcceptanceなしにEnergy内部を拡張しない。
- Safety: opt-in隔離modeでGodot所有のstatic danger zone、または別fixtureのmoving threatをbounded contextへ投影する。NPC Bはsafe Plazaを固定targetとして `flee`、exposure消失後も継続し、Plaza到達の後続観測で `idle / COMPLETE` に戻る。moving fixtureは位置だけを更新し、predator ontology・負傷・Energy連携はまだ行わない。
- Safety selection: Godotはsafe/uncertainと有限距離bandの候補記述だけを渡す。Runtimeの独立selectorが `safe > uncertain`、同安全度なら近い候補を一度だけ選び、その後の順位変化はTrajectory targetを変えない。
- Danger selection: Godotは現在接触中のdanger sourceと `low / medium / high` だけを渡す。Runtimeは支配sourceを有限選択してprovenanceへ残すが、safe target・Energy・負傷には権限を持たない。
- Workbench visualization: [V1-V3 contract](docs/experiment-contracts/WORKBENCH_visualization_contract.md)でNPC・Object・Threat・Placeを簡易図形化し、選択NPCの観測円、既存committed target線、static danger領域を表示する。World truth・Runtime decision・canonical sidecarには非介入。Inspector V4は目視評価後まで保留。
- Continuous life: Phase A〜Eでresult因果拘束、Safety通常CLI、実三周Food自律、inspector/simulation分離、Food-Safety有限統合まで成立。Phase Fの[長期縦断証拠](docs/experiment-evidence/CONTINUOUS_LIFE_reference_evidence.md)では、別Shelterへの退避を含む成功→通常成功→cueなし自律完走を同一NPC/Runtime/Worldで確認する。Phase Gでは優先Godot縦断をCI固定する。一般Need arbitrationは未実装。
- Food × Rest: 明示opt-inの[有限Coordinator](docs/experiment-contracts/FOOD_REST_continuous_life_contract.md)で、Food保持中の高RestNeed→Food保留→別Rest Hutでshort rest→現在関係からFood再評価→Plaza帰還/depositを確認する。固定閾値による最初の比較sliceであり、一般Need arbitrationではない。
- Incapacitation Phase 5A: 専用[Safety failure contract](docs/experiment-contracts/SAFETY_incapacitation_contract.md)で、3回のfixture-controlled failed flee→Godot-owned severe injury / incapacitated→後続Runtime actionのidle拘束を確認する。通常Safetyへは非介入で、Rescue / Recoveryは未実装。
- Rescue Phase 5B: [bounded discovery contract](docs/experiment-contracts/RESCUE_bounded_discovery_contract.md)で、観測範囲内の別NPCだけがincapacitated conditionを受け取る。global通知、Rescue Goal、搬送、回復は未実装。
- Rescue Phase 5C: [Goal / Trajectory contract](docs/experiment-contracts/RESCUE_goal_trajectory_contract.md)で、bounded discoveryからtargetを一度固定し、対象へ接近して `READY_TO_RESCUE` で停止する。搬送・治療・回復は未実装。
- Rescue Phase 5D: [safe-place delivery contract](docs/experiment-contracts/RESCUE_safe_delivery_contract.md)で、対象保持、固定safe targetへの搬送、World-owned delivery記録、後続観測によるCOMPLETEまで通す。治療・回復は未実装。
- Rescue Phase 5E: [staged recovery contract](docs/experiment-contracts/RESCUE_staged_recovery_contract.md)で、安全地点滞在中の有限4段階回復をGodot BodyStateが所有する。回復後は旧Safety trajectoryを盲目的に再開せず、現在関係で再評価する。
- Rescue Phase 5F: [multi-agent reference evidence](docs/experiment-evidence/RESCUE_multi_agent_reference_evidence.md)で、NPC Bの行動不能からNPC Aの発見・一度だけの救助・搬送・段階回復までを同一World/Runtimeで固定する。回復中conditionは再救助候補から分離する。
- Sleep S1-S4 + Fast F1/F2の記憶循環に加え、C1でCore `3270982`のauthority境界を固定した。C2では[Canonical Review Path](docs/experiment-contracts/CANONICAL_review_path_projection_contract.md)として`RIB_B/F/RIB_B'/F'/E/review/H`を追跡し、C3では[finite theta_eff](docs/experiment-contracts/CANONICAL_theta_effective_contract.md)を独立評価する。C4では[finite M_delta transition](docs/experiment-contracts/CANONICAL_M_delta_transition_contract.md)としてexplicit review時だけ再編相へ入場し、p5へread-only表示する。本線の次段はT1-A。
- T1-A前の[Multi-Agent / Territory Beast検証](docs/design/RDL_GameAI_C4後_Multi-Agent_Territory_Beast検証計画.md)はR1-R7完了。3/5/10 agentsの分離、Fast cross-agent境界、danger labelを持たないWorld fixture、warning/chase/attack、direct/observer Experience、C1-C4非介入をEvidence化し、本線へ復帰した。
- [T1-A Material Expansion](docs/experiment-contracts/T1_material_expansion_contract.md)ではactive `M_delta`からcurrent `M_B`、RIB history、unresolved residual、same-agent Candidate/Experienceを不変bundleへ展開し、全材料を`UNINSPECTED`でT1-Bへ渡す。
- [T1-B Material Selection](docs/experiment-contracts/T1_material_selection_contract.md)ではbundle全材料を根拠・evidence・revision付きで`RETAIN / REJECT / DEFER`へ明示選別する。T1-B単独の`RETAIN`は採用ではなく、T1-Cへの明示入力となる。
- [T1-C Reconstruction](docs/experiment-contracts/T1_reconstruction_contract.md)ではretained parent/candidateから別identityのinactive `M_B'`を生成する。old `M_B`、active registry、`M_delta`は不変のままDMB-Aへ渡す。
- [Dynamic M_B Inactive Cycle](docs/experiment-contracts/DYNAMIC_MB_inactive_cycle_contract.md)ではExperience/candidate系とcanonical rupture系をT1-Aでのみ明示合流し、inactive `M_B'`まで一本のprovenanceを固定した。ExperienceがHを生成したとは扱わず、DMB-Bへ明示入力する。
- [Dynamic M_B Cutover / Re-entry](docs/experiment-contracts/DYNAMIC_MB_cutover_reentry_contract.md)ではparentをarchiveし、`M_B'`をactive evaluatorへ切替え、fresh comparison windowで通常相へ戻す。これはgame action authorityではなく、DMB-Cでmulti-agent回帰を確認する。
- [Dynamic M_B Multi-Agent Regression](docs/experiment-contracts/DYNAMIC_MB_multi_agent_regression_contract.md)では2個体が別candidate・model・archive・`M_delta`・fresh windowで一周することを確認した。local actionはcutover前後で不変。
- [G1 Godot Dynamic M_B Reintegration](docs/experiment-contracts/G1_Godot_dynamic_mb_reintegration_contract.md)ではGodot所有の身体・空間・実行動から既存DMB経路へ再接続し、cutover後のfresh Godot比較とlocal action不変を固定した。
- [G2-A Long-Life Dynamic M_B](docs/experiment-contracts/G2A_long_life_dynamic_mb_contract.md)では同一Godot Worldでday 1のFood/Safety、実Sleep、明示DMB cutover、day 2のcueなし自律Foodを接続した。
- [G2-B Multi-Agent Long-Life](docs/experiment-contracts/G2B_multi_agent_long_life_contract.md)では同一World/Runtime内のNPC A/Bが別candidate・model・archive・`M_delta`・habitを保ち、それぞれ翌日のcueなし自律Foodを完走した。実行は決定論的な直列fixtureである。
- [Risky Tasty Food Reference](docs/experiment-contracts/RISKY_TASTY_FOOD_reference_contract.md)ではordinary/tasty Food、物理的Territory関係、source付きGod Statue statement、既存warning/chase/attack/injury、Food関係付きExperienceを同一参照fixtureへ置いた。statement・Experience・Dynamic `M_B`にaction authorityはない。
- Display: action・body・history由来のResponse Expression。心理的感情推定や行動権限ではありません。
- Deferred: canonical action authority、DNA・動的神経値・World Time・会話、栄養・一般在庫・飢餓等の広い生活機能。

固定retry profileは神経値から導出したものではありません。設計上の「DNA μ/σ → dynamic neural state → derived sensitivity」と現行実装を区別します。

[Runtime evidence](docs/experiment-evidence/CURRENT_v23_runtime_evidence.md)と[層間分離契約](docs/experiment-contracts/CROSS_LAYER_separation_contract.md)が確認範囲を示します。保持はprocess-localであり、再起動永続化を意味しません。

## Semantic boundaries

意味論の基準は[Core reference](docs/semantic-reference/RDL_Core_T0_T1_reference.md)の同期点 `3270982`（BASE v2.3 / SPEC v2.4 + dynamic theta explanation）。Demos・Enterprise・Humanは素材・仮説の参照元、General ModulesのLayeringは整理補助です。

```text
Engine state != observation != RIB_B != M_B
F / F' use the same frozen pre-update M_B
Structural Conflict != E != H
nonzero E != unresolved by definition
H != emotion / Human Attention
Novelty != ξ
Player statement != World Truth
semantic fallibility allowed; structural integrity required
```

誤認・誤命名・誤一般化は設計上許容しますが、参照破損・provenance消失・意図しないcanonical mutationは許容しません。詳細は[設計手法](docs/design/RDL_GameAI_設計手法.md)へ。

## Run

```bash
python -m runtime.bridge
```

p5.js Viewerは別端末で `python gui-p5/serve.py` を起動し、`http://127.0.0.1:8080` を開きます。GUI側proxyはGETのみをRuntimeへ転送し、状態変更要求は受け付けません。

Assisted Base–Food実験は明示的に有効化します: python -m runtime.bridge --base-food-life

Godot 4.7で [project.godot](godot/rdl-game-ai-workbench/project.godot) を開き、Run Projectを実行します。RuntimeモードでPython bridgeに接続します。MockモードはGodot単体です。

履歴の行動影響は任意です。

```bash
python -m runtime.bridge --history-influence --retry-profile npc_a=long --retry-profile npc_b=short
```

観測IDを再利用するWorkbench Reset後はRuntimeも再起動してください。API・容量・review・停止境界の詳細は[現行契約](docs/experiment-contracts/CURRENT_v23_runtime_contract.md)と各機能契約を参照します。

## Verify

```powershell
$env:GODOT_BIN = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
python -m unittest discover -s tests -v
```

GODOT_BINなしではGodot連携テストはskipされます。テスト成功は宣言した有限Boundary内の確認であり、全ゲーム挙動やRDL理論の証明ではありません。

## Repository

```text
docs/design/                design map and responsibility documents
docs/semantic-reference/    pinned Core reading
docs/source-inventory/      source-mine evaluations
docs/experiment-contracts/  finite runtime contracts
docs/experiment-evidence/   verification records
notes/experiment-roadmap.md canonical maturity
runtime/                   local action runtime and diagnostic sidecar
godot/                     world and interaction workbench
gui-p5/                    read-only p5.js observation / provenance viewer
experiments/                bounded prototypes
tests/                     acceptance tests
```

[文書棚卸し](docs/design/DOCUMENT_STATUS.md)に整理理由を記録しています。
