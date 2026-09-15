# RDL Game AI Lab

`RDL_GameAI_Lab` is an experimental playground for building **interesting game AI rather than merely strong game AI**.

> **世界・他者・自身の履歴との相互作用によって、理解可能だが固定されない振る舞いを生むAIを検証する。**

`RDL_Demos`、`RDL_Enterprise`、`RDL_Human` は素材鉱山として扱い、意味論の権威は `Aporapeiron/RDL_Core` T0/T1 v2.3 に置く。

## Current references

- [Core v2.3 semantic reference](docs/semantic-reference/RDL_Core_T0_T1_reference.md)
- [GameAI design method](docs/design/RDL_GameAI_設計手法.md)
- [Affect / history / relational constraint model](docs/design/RDL_GameAI_感情・履歴・関係拘束モデル.md)
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

No unresolved classification or H is inferred from E magnitude.

## Runtime

```bash
python -m runtime.bridge
```

```text
POST /v1/observe
GET  /health
GET  /v1/canonical-snapshot
```

The snapshot exposes current finite `RIB_B`, diagnostic `M_B`, interpretations, and E provenance.

## Source mines — current reading

### RDL_Demos

Use current Village v2.3 for finite B/RIB_B, same-frozen M_B comparison, explicit unresolved review, H/θ/M_Δ, T1 reconstruction, finite-context authority, fresh re-entry, and operational coverage. Legacy/local `LocalLoadVector`, `ExplorationState`, `LeapEngine`, `HVec`, `XiPool`, and `Boundary` are not Core semantics by name.

### RDL_Enterprise

Use current v2.3 bounded acquisition, `RIBSection`, frozen interpretation context, provenance/coverage separation, restart durability, staged commitment/authority, and changed-condition acceptance. Human Attention, static structural conflict, coverage metrics, and compatibility `*CompiledMB` names are not Core H/E/ξ/M_B by identity.

### RDL_Human

Use as a v2.3-aligned T3 hypothesis mine. Human-specific heat, SFO, self-boundary, cognitive-space, affect, and temporal models remain application hypotheses rather than Core primitives.

## Next boundary

The next step is finite assessment of E:

```text
zero
pending
resolved
ordinary temporal change
boundary / coverage change
unresolved
```

Only reviewed unresolved dimensions may later enter `H_vec -> H -> θ`.

After that:

```text
relation history
→ sensitivity / affect
→ M_Δ / T1 reconstruction
→ finite-context authority / fresh re-entry
→ long-run richness
```

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
