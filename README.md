# RDL Game AI Lab

`RDL_GameAI_Lab` is an experimental playground for building **interesting game AI rather than merely strong game AI**.

> **世界・他者・自身の履歴との相互作用によって、理解可能だが固定されない振る舞いを生むAIを検証する。**

`RDL_Demos`、`RDL_Enterprise`、`RDL_Human` は素材鉱山として扱い、意味論の権威は `Aporapeiron/RDL_Core` T0/T1 v2.3 に置く。

## Current references

- [Core v2.3 semantic reference](docs/semantic-reference/RDL_Core_T0_T1_reference.md)
- [GameAI design method](docs/design/RDL_GameAI_設計手法.md)
- [Affect / history / relational constraint model](docs/design/RDL_GameAI_感情・履歴・関係拘束モデル.md)
- [NPC layering profile](docs/design/RDL_GameAI_NPC_レイヤリング_Profile.md)
- [NPC layer-based design plan](docs/design/RDL_GameAI_NPC_レイヤー別設計計画.md)
- [Current runtime contract](docs/experiment-contracts/CURRENT_v23_runtime_contract.md)
- [Current runtime evidence](docs/experiment-evidence/CURRENT_v23_runtime_evidence.md)
- [Roadmap](notes/experiment-roadmap.md)

## Current semantic boundary

```text
SILN participates in one or more RIBs
Purpose / finite B selects RIB_B
Engine world state != Agent Observation != RIB_B != Agent M_B
F / F' use the same frozen pre-update M_B
E = Δ(F,F')
nonzero E != unresolved by definition
only finite-reviewed unresolved remainder may enter H
H != fear / fun / jealousy / stress / Human Attention
Structural Conflict != E != H
∀B_finite: ξ(B) != 0
ξ != runtime uncertainty / coverage / novelty / exploration scalar
```

## NPC layering profile — design-only

`Aporapeiron/RDL_General_Modules` の **RDL 横断レイヤリング・キット**を、GameAI-localな整理Viewとして適用する。

```text
Generation / DNA
      ↓
Neural / Sensitivity
      ↓
Physical / Body
      ↓
Experience / Relation History
      ↓
Realtime / Current Context
```

このProfileはNPCの普遍的存在論でも、Core `M_B` の分解定義でもない。

```text
SensitivityProfile != M_B by identity
BodyState          != M_B by identity
RelationHistory    != M_B by identity
CurrentContext     != M_B by identity
```

現在は **design-only**。canonical sidecar、existing action path、graph / reconstruction authorityは変更しない。relation historyとindividual sensitivityの実験を進める際に、Layer別read-only snapshotから段階導入する。

## Current vertical slice

The live mock workbench + Python runtime currently reaches E while keeping canonical observation read-only:

```text
Godot engine reference state
→ bounded agent observation
→ existing Python structured action
→ Godot world resolution
→ changed interaction conditions
→ subsequent bounded observation

accepted bounded observation
→ Purpose / finite B / selected dimensions / conditions / coverage / provenance
→ RIB_B
→ frozen diagnostic M_B
→ F / F'
→ E
```

The canonical sidecar runs only after the existing action path accepts a packet. It cannot alter the returned action.

Current selected GameAI-local dimensions:

```text
visible_agents_count
visible_objects_count
visible_places_count
```

Missing selected coverage is not invented as zero. A boundary-condition change opens a different comparison window. `F/F'` comparison requires the same frozen `model_ref`.

Current E is explicitly labeled:

```text
E-only-not-reviewed
```

No unresolved classification or H is inferred from E magnitude. A separate finite assessment ledger now accepts explicit per-dimension reviews and exposes single-comparison residual H. The original E record remains unchanged.

## Runtime

```bash
python -m runtime.bridge
```

```text
POST /v1/observe
GET  /health
GET  /v1/canonical-snapshot
POST /v1/assessment-review
POST /v1/interaction-result
GET  /v1/experience-snapshot
```

The snapshot exposes current finite `RIB_B`, diagnostic `M_B`, interpretations, and E provenance.

## Source mines — current reading

### RDL_Demos

Use current Village v2.3 for finite B/RIB_B, same-frozen M_B comparison, explicit unresolved review, H/θ/M_Δ, T1 reconstruction, finite-context authority, fresh re-entry, and operational coverage. Legacy/local `LocalLoadVector`, `ExplorationState`, `LeapEngine`, `HVec`, `XiPool`, and `Boundary` are not Core semantics by name.

### RDL_Enterprise

Use current v2.3 bounded acquisition, `RIBSection`, frozen interpretation context, provenance/coverage separation, restart durability, staged commitment/authority, and changed-condition acceptance. Human Attention, static structural conflict, coverage metrics, and compatibility `*CompiledMB` names are not Core H/E/ξ/M_B by identity.

### RDL_Human

Use as a v2.3-aligned T3 hypothesis mine. Human-specific heat, SFO, self-boundary, cognitive-space, affect, and temporal models remain application hypotheses rather than Core primitives.

### RDL_General_Modules

Use the current `RDL 横断レイヤリング・キット` as a lightweight organization aid. It may structure GameAI-local generation, sensitivity, body, history, and realtime conditions, but does not override Core semantics or confer runtime authority.

## Next boundary

The Inspector now offers full/limited/stopped movement for the selected NPC.
Godot owns the body state and enforces displacement; Runtime consumes a bounded
self snapshot. See the [Body movement contract](docs/experiment-contracts/BODY_movement_contract.md).

The optional history policy now supports fixed per-agent retry tendencies:
`--history-influence --retry-profile npc_a=long --retry-profile npc_b=short`.
This is the first bounded individual-response experiment; see the
[sensitivity profile contract](docs/experiment-contracts/SENSITIVITY_retry_profile_contract.md).

Finite assessment now supports:

```text
zero
pending
resolved
ordinary temporal change
boundary / coverage change
unresolved
```

Only explicitly reviewed unresolved dimensions enter diagnostic `H_vec -> H`. Both per-comparison H and retained H per exact context/frozen model are available. The local retention rule sums latest reviewed residuals until explicit resolution, without time decay or signed cancellation. θ, automatic review, and action authority remain deferred. See the [review API and finite contract](docs/experiment-contracts/CURRENT_v23_runtime_contract.md#finite-assessment-api).

The first read-only Experience slice now records reported approach outcomes,
keeping progress/no-progress histories separate per agent, target, and context.
Storage remains separate from action authority. The optional [history retry experiment](docs/experiment-contracts/EXPERIENCE_influence_contract.md) uses recent no-progress history to defer a visible target for three ticks. Enable it with `python -m runtime.bridge --history-influence`. See the [Experience contract](docs/experiment-contracts/EXPERIENCE_history_contract.md).

Remaining sequence:

```text
relation history
→ sensitivity / affect
→ M_Δ / T1 reconstruction
→ finite-context authority / fresh re-entry
→ long-run richness
```

The layering profile follows that order rather than bypassing it:

```text
Experience / Relation History
→ Neural / Sensitivity
→ reviewed cross-layer influence
```

Generation / DNA and reproduction remain deferred.

## Tests

```bash
python -m unittest discover -s tests -v
```

A green test means only that no contract violation was observed inside the declared finite test Boundary.

```text
current finite Boundaryで operationally sufficient
!= terminally complete
!= universally valid
!= all game behavior evaluated
```

## Repository shape

```text
docs/
  semantic-reference/   current Core reading
  source-inventory/     current source-mine evaluations
  design/               current GameAI design documents
  experiment-contracts/ current runtime contract
  experiment-evidence/  current runtime evidence
runtime/                 action runtime + read-only canonical sidecar
godot/                   bounded world / interaction workbench
experiments/             small runnable prototypes
notes/                   forward roadmap
tests/                   Python acceptance tests
```
