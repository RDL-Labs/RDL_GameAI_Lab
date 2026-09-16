# Experiment Roadmap

This roadmap starts from the **current** Core v2.3 runtime state. Superseded phase-by-phase P1/P2/P3 history is kept in Git history rather than in the active working tree.

## Current state

Implemented and covered by the current runtime contract/evidence:

```text
engine/world reference state
!= bounded agent observation
!= RIB_B
!= M_B

bounded observation
→ existing action
→ actual Godot world resolution
→ changed interaction conditions
→ subsequent bounded observation

accepted observation
→ Purpose / finite B / selected dimensions / conditions / coverage / provenance
→ RIB_B
→ same frozen pre-update M_B
→ F / F'
→ E = Δ(F,F')
```

Current stop rule:

```text
E exists
!= unresolved established
!= H established without explicit review
```

The canonical path is read-only and does not yet own action/reconstruction authority.

## Layering view — design-only

The current NPC layering profile is an organization aid for future GameAI-local state, not a cutover of runtime authority.

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

```text
Layer Profile
!= Core M_B decomposition
!= action authority
!= graph mutation authority
```

The roadmap below determines when each layer may become operational.

Use the [NPC layer design plan v0.2](../docs/design/RDL_GameAI_NPC_レイヤー別設計計画.md#111-状態の所有更新保持) as the shared design blueprint. For each new state, specify its owner, update trigger, retention, influence path, provenance, and controlled comparison test. Layers do not prescribe a class hierarchy or require simultaneous implementation.

Introduce each cross-layer path as a read-only snapshot first, then enable its influence under an explicit acceptance contract. Keep one owner per state; derived context snapshots retain their source identity. Retention within an experiment does not imply restart persistence.

## Next 1 — finite assessment / unresolved residual / H

Implemented bounded slice: explicit per-dimension review with basis/reviewer/evidence, pending by default, diagnostic single-comparison residual `H_vec / H`, and retained H scoped to exact context/frozen model. The GameAI-local baseline retains latest reviewed residual magnitudes until explicit resolution; no time decay or signed cancellation. Replay/re-review cannot add the same contribution twice. Capacity and semantic repeated-event review limits are documented in the current contract. θ and action authority remain deferred. The layer design plan's `E-only-not-reviewed` label describes the unchanged raw E record; assessment is a separate record.

Goal:
- classify E without treating magnitude as unresolved by definition;
- route only explicitly reviewed unresolved dimensions into H.

Required distinctions:

```text
zero
pending
resolved
ordinary temporal change
boundary / coverage change
unresolved
```

Acceptance:
- nonzero E alone is insufficient for H;
- finite basis / reviewer / evidence provenance are explicit for unresolved classification;
- only unresolved dimensions enter `H_vec`;
- the chosen `H = ||H_vec||` norm is explicitly GameAI-local;
- fear/fun/jealousy/stress/Human Attention/static conflict cannot directly increment H.

## Next 2 — relation history / Experience Layer

Read-only first slice implemented: admitted Runtime approach decisions are matched to bounded Godot result reports, with source/subsequent observation IDs, agent/target/context separation, and separate progress/no-progress histories. See [the Experience contract](../docs/experiment-contracts/EXPERIENCE_history_contract.md). Retention is 128 admitted decisions per process with no eviction. History-driven behavior and social positive/negative relation semantics remain the next acceptance boundary; they are not established by movement-result history alone.

Goal:
- prior interaction history changes present interpretation and action;
- operationalize the first persistent part of the NPC layering profile without collapsing it into Core `M_B` by identity.

Bounded action influence is now available behind `--history-influence`: recent no-progress history defers a visible approach target for three ticks. Controlled same-observation comparisons and actual Workbench HTTP tests validate the effect. Canonical history-dependent interpretation and social relation semantics remain open; see [the influence contract](../docs/experiment-contracts/EXPERIENCE_influence_contract.md).

Acceptance:
- the same present event can yield different interpretation/behavior after different finite histories;
- positive and negative relation histories may coexist;
- history is finite provenance, not complete world truth;
- `RelationHistory != M_B by identity` remains explicit;
- any Experience-layer snapshot is read-only until a separately reviewed influence path is accepted.
- declare history retention/forgetting and event provenance; compare histories while holding current observation, body, and sensitivity fixed;
- changes affecting canonical interpretation use an explicit model/context boundary and never mutate M_B within an F/F' comparison.

Experiential check:

> **同じNPCを数日眺めたとき、「こいつ昨日のこと引きずってるな」と感じられるか。**

## Next 3 — individual sensitivity / affect expression / Neural Layer

Minimal Body slice implemented: selected-agent movement capability is owned by
Godot, projected as a self snapshot, and applied to action eligibility and world
resolution. Full/limited/stopped controls and recovery are tested over real HTTP.
See [the Body contract](../docs/experiment-contracts/BODY_movement_contract.md).
This is an intervention experiment, not injury/fatigue dynamics or affect.

Minimal fixed response-profile slice implemented: per-agent short/standard/long retry windows (1/3/5 ticks), immutable within a run. Same-history/same-observation comparisons establish a local action difference; actual Godot verifies short-profile retry after one tick. See [the profile contract](../docs/experiment-contracts/SENSITIVITY_retry_profile_contract.md). This does not complete multi-dimensional sensitivity, Body, affect expression, learned updates, or social history.

Goal:
- separate sensitivity from learned history and derive visible affect as a GameAI-local layer;
- connect Neural / Sensitivity with Experience, Body, and Current Context without turning the layer map into a Core ontology.

Candidate dimensions:

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
stability_preference
control_loss_sensitivity
recoverability_sensitivity
```

Acceptance:
- same history/context can yield different behavior across profiles;
- sensitivity is not personality, relation strength, Core H, Core ξ, or Core M_B by identity;
- similar total H may yield different affect because provenance/history/context differ;
- visible affect remains derived rather than T0 primitive;
- cross-layer influence has explicit finite inputs, provenance, and break conditions.
- vary sensitivity, body, or current context one at a time before testing combined effects; record unchanged outcomes as well as changed behavior;
- assign body values such as fatigue to one owner and expose sourced snapshots to current context.

## Next 4 — M_Δ / T1 reconstruction

```text
H >= θ
→ M_Δ
→ current M_B as SILN_SELF
→ Probe
→ Expansion
→ Inspection
→ Selection
→ Reconstruction
→ M_B'
```

Acceptance:
- H is entry evidence, not an update vector;
- Selection distinguishes `retain / reject / defer`;
- retained relations, valid conditions, break conditions, unresolved items, and provenance are explicit;
- `M_B'` remains finite and continues to leave ξ.

Layering note:
- GameAI-local Experience / Sensitivity / Body / Context may provide finite conditions or provenance to a reconstruction experiment;
- they do not become canonical `M_B` fields merely because they are arranged in a Layer Profile.

## Next 5 — finite-context authority / fresh re-entry

Goal:
- activate reconstructed `M_B'` only inside the finite context supported by evidence.

Acceptance:
- shadow/fresh re-entry evidence precedes cutover;
- authority is scoped by B / Purpose / selected conditions;
- one context is not silently generalized to another;
- outside migrated contexts previous behavior remains available until separately reviewed.

## Next 6 — richness / long-run behavior

Observe separately:

```text
behavior variety
individual divergence
history dependence
relation dependence
place meaning drift
daily variation
readability
surprise
recoverability
rupture diversity
```

Acceptance:
- no single survival/win scalar defines success;
- observed diversity is not merely randomness;
- long-run behavior remains inspectable through finite provenance.

## Deferred until a break requires them

```text
Generation / DNA runtime implementation
reproduction / inheritance / evolution
epigenetic / development layer
large-scale Canary / Shadow / Promotion stack
Human Attention workflow
advanced structure induction
large-scale long-horizon learning
advanced LLM dialogue
complex economy
culture generation
```

Generation / DNA is already defined as a design layer, but no current runtime work depends on it.

## Global stop rule

A boundary may be considered operationally sufficient only inside its declared finite conditions.

```text
current finite Boundaryで operationally sufficient
!= terminally complete
!= universally valid
!= all NPC behavior evaluated
!= RDL theory proven
```

The same applies to the Layer Profile:

```text
Complete_B(NPC Layer Profile) = true
and
ξ(B) != 0
```
