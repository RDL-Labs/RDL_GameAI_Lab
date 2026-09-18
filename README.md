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

生活機能の追加順は[Game Feature Roadmap](docs/design/RDL_GameAI_実装手順予定.md)で管理します。

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
- Current direction: Restの固定target・interrupt復帰に加え、[最小Sleep生活行動](docs/experiment-contracts/SLEEP_life_action_contract.md)としてRestNeed + 明示window + safe place → sleep → 回復を実縦断した。World TimeとSleep Consolidationは未実装。神の像にaction authorityは与えない。
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
- Display: action・body・history由来のResponse Expression。心理的感情推定や行動権限ではありません。
- Deferred: θ / M_Δ / T1 reconstruction / canonical action authority、DNA・動的神経値・Sleep Consolidation・World Time・会話、栄養・一般在庫・飢餓等の広い生活機能。

固定retry profileは神経値から導出したものではありません。設計上の「DNA μ/σ → dynamic neural state → derived sensitivity」と現行実装を区別します。

[Runtime evidence](docs/experiment-evidence/CURRENT_v23_runtime_evidence.md)と[層間分離契約](docs/experiment-contracts/CROSS_LAYER_separation_contract.md)が確認範囲を示します。保持はprocess-localであり、再起動永続化を意味しません。

## Semantic boundaries

意味論の基準は[Core reference](docs/semantic-reference/RDL_Core_T0_T1_reference.md)の同期点 `9c60c5b`（BASE v2.3 / SPEC v2.4）。Demos・Enterprise・Humanは素材・仮説の参照元、General ModulesのLayeringは整理補助です。

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
experiments/                bounded prototypes
tests/                     acceptance tests
```

[文書棚卸し](docs/design/DOCUMENT_STATUS.md)に整理理由を記録しています。
