# RDL Game AI Lab

`RDL_GameAI_Lab` is an experimental playground for building **interesting game AI rather than merely strong game AI**.

The target is behavior that becomes understandable through history and relationships without becoming completely fixed or predictable.

> **世界・他者・自身の履歴との相互作用によって、理解可能だが固定されない振る舞いを生むAIを検証する。**

This repository treats `RDL_Demos`, `RDL_Enterprise`, and `RDL_Human` as source mines. Their implementations and hypotheses are working material, not semantic authority. Canonical semantics are checked against `Aporapeiron/RDL_Core` T0/T1 v2.3.

## Semantic Baseline

- [RDL_Core T0/T1 semantic reference](docs/semantic-reference/RDL_Core_T0_T1_reference.md)
- [Game AI design method](docs/design/RDL_GameAI_設計手法_DRAFT_v0.1.md)
- [Experiment roadmap](notes/experiment-roadmap.md)

Current invariants:

```text
SILN participates in one or more RIBs
Purpose / finite B selects a finite action-section RIB_B
Engine world state != Agent Observation packet != RIB_B != Agent M_B
F / F' use the same frozen pre-update M_B
E = Δ(F, F')
nonzero E != unresolved by definition
only finite-assessed unresolved remainder may enter H
H != fear / fun / jealousy / stress / Human Attention
static Structural Conflict != E != H
∀B_finite: ξ(B) != 0
ξ != runtime uncertainty / coverage / novelty / exploration scalar
```

## Current Vertical Slice

P1 and P2 are already accepted as pre-canonical interaction evidence:

```text
Godot engine reference state
→ bounded observation packet
→ Python structured action
→ Godot actual world resolution
→ changed interaction conditions
→ subsequent bounded observation
```

The new Core v2.3 migration inserts an explicit acquisition boundary before any `F/F'/E` work:

```text
bounded observation packet
→ Purpose / finite B acquisition
→ selected dimensions + conditions + coverage + provenance
→ RIB_B
```

Current read-only sidecar stops there. It intentionally does **not** create agent `M_B`, `F`, `F'`, `E`, `H`, `M_Δ`, or T1 state.

## Read-only Canonical Acquisition Sidecar

The Python bridge now observes accepted bounded packets after the existing action decision path and records a diagnostic finite section.

Current selected demo-local dimensions:

```text
visible_agents_count
visible_objects_count
visible_places_count
```

These are not Core-required variables.

Run the bridge:

```bash
python -m runtime.bridge
```

Existing action endpoint:

```text
POST /v1/observe
```

Read-only canonical snapshot:

```text
GET /v1/canonical-snapshot
```

The snapshot reports:

```text
authority = read-only-acquisition-sidecar
stage = RIB_B-acquisition-only
source observation id
Purpose / boundary id
selected dimensions
coverage
provenance
xi_status = unrecovered-relations-remain
```

Missing selected coverage is not invented as zero. The sidecar cannot change the action response.

## Source Mines — Current Reading

### RDL_Demos

Current Village v2.3 is valuable for:

```text
finite B / RIB_B
same-frozen M_B comparison
explicit unresolved review
H / theta / M_delta
T1 Probe / Selection / Reconstruction
finite-context authority
fresh re-entry
operational coverage
```

Legacy/local `LocalLoadVector`, `ExplorationState`, `LeapEngine`, and aliases such as `HVec / XiPool / Boundary` are not Core semantics by name.

### RDL_Enterprise

Current Enterprise v2.3 is valuable for:

```text
bounded acquisition
RIBSection
frozen interpretation context
provenance / coverage separation
restart durability
staged commitment / authority
changed-condition acceptance harness
```

Enterprise-local Human Attention, static structural conflict, coverage metrics, and compatibility `*CompiledMB` names are not Core `H / E / ξ / M_B` by identity.

### RDL_Human

Current Human is a v2.3-aligned T3 hypothesis mine. Human-specific heat, SFO, self-boundary, cognitive-space, affect, and temporal models remain application hypotheses rather than Core primitives.

## Experiment Themes

1. **Interaction-grounded NPC behavior**
   - bounded observation, explicit acquisition, actual world response, later observation.

2. **History, relation, and affect expression**
   - affect is derived from finite interaction history, relation state, sensitivity, body state, context, and unresolved provenance when present.

3. **Learning without policy collapse**
   - T1-style Probe → Expansion → Inspection → Selection → Reconstruction.
   - preserve contextual coexistence where supported.

4. **Living-world simulation**
   - reuse Village world/body/perception/relation/dialogue ideas without importing legacy Core-like aliases as semantics.

5. **Richness metrics**
   - behavior variety, individual divergence, history dependence, relation dependence, place-meaning drift, readability, surprise, recoverability, rupture diversity.

6. **Browser-sized demos**
   - small inspectable experiments before integrated worlds.

## Current Experiment Status

```text
P0 Core v2.3 + source-mine resync      current migration
P1 bounded perception                  accepted
P2 actual interaction loop             accepted
P3 canonical RIB_B acquisition         first read-only implementation
P4 frozen M_B / F / F' / E             next
P5 finite unresolved review / H         later
P6 relation history                     later
P7 sensitivity / affect                 later
P8 M_delta / T1 reconstruction          later
P9 finite-context authority / re-entry  later
P10 richness / long-run behavior        later
```

## Tests

Python:

```bash
python -m unittest discover -s tests -v
```

Godot P2 interaction check remains the existing acceptance path documented in `docs/experiment-evidence/P2_interaction_loop_evidence.md`.

A green test means only that no contract violation was observed inside the declared finite test Boundary.

```text
current finite Boundaryで operationally sufficient
!= terminally complete
!= universally valid
!= all game behavior evaluated
```

## Repository Shape

```text
docs/
  semantic-reference/   current Core semantic reading
  source-inventory/     current source-mine evaluations
  design/               GameAI-specific design drafts
  experiment-contracts/ bounded acceptance contracts
  experiment-evidence/  acceptance evidence
runtime/
  existing action runtime
  read-only v2.3 acquisition sidecar
godot/
  bounded world / interaction workbench
experiments/            small runnable prototypes
notes/                  roadmap and logs
tests/                  Python runtime and canonical-sidecar tests
```
