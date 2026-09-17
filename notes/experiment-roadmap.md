# Experiment Roadmap

This roadmap starts from the current runtime state, synchronized to Core `9c60c5b` (BASE v2.3 / SPEC v2.4). Superseded phase-by-phase P1/P2/P3 history is kept in Git history.

Role: axis A in the [overall map](../docs/design/RDL_GameAI_全体設計地図.md), tracking canonical operational maturity and separation of adjacent local influences. It depends on the [runtime contract](../docs/experiment-contracts/CURRENT_v23_runtime_contract.md) and [evidence](../docs/experiment-evidence/CURRENT_v23_runtime_evidence.md).
It does not own game-feature phases; those belong to the [life-feature roadmap](../docs/design/RDL_GameAI_実装手順予定.md). Canonical maturity != game feature phase.

## Maturity summary

Numbers below identify review areas, not one canonical computation chain. Local history/body/profile/expression are adjacent influence experiments, not additional Core primitives or mandatory stages between H and M_Δ.

| Area | Implemented slice | Remaining boundary |
|---|---|---|
| 1. Finite assessment / H | Explicit review, residual H and retained H by exact frozen context | Automatic classification, decay, restart durability; θ not implemented |
| 2. Experience influence (local) | Bounded approach history and opt-in retry policy | Social relations, compressed constraints, sleep/dialogue history |
| 3. Local profile / Body / Expression | Fixed 1/3/5 tick retry, movement_scale, sourced display projection | Dynamic Neural Dynamics, neural-derived sensitivity, psychological affect |
| 4. M_Δ / T1 | Not implemented | Trigger, finite Probe / selection / reconstruction contract |
| 5. Authority / fresh re-entry | Not implemented | Reviewed M_B' activation in finite context |
| 6. Long-run richness | No acceptance established | Long-run controlled observation and provenance |

Existing cross-layer separation tests cover bounded combinations only; they do not establish dynamic neural or sleep systems.

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
→ explicit finite review
→ H / retained H per exact context and frozen model
```

Continuing invariant (not the current stopping point):

```text
E exists
!= unresolved established
!= H established without explicit review
```

The canonical path is read-only and does not yet own action/reconstruction authority.

## Layering view with bounded operational slices

The profile organizes local Experience, fixed Sensitivity, Body, and Realtime implementations. Expression is derived display-only. DNA is deferred. These do not acquire canonical action/reconstruction authority.

```text
Generation / DNA
      ↓
Neural Dynamics
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

Sections 1-3 below retain adoption order and broader goals; their minimal slices are already operational, not future work in their entirety. Before T1, validate the [cross-layer separation contract](../docs/experiment-contracts/CROSS_LAYER_separation_contract.md).

Use the [NPC layer design plan](../docs/design/RDL_GameAI_NPC_レイヤー別設計計画.md#11-状態の所有更新保持) as the shared design blueprint. For each new state, specify its owner, update trigger, retention, influence path, provenance, and controlled comparison test. Layers do not prescribe a class hierarchy or require simultaneous implementation.

Introduce each cross-layer path as a read-only snapshot first, then enable its influence under an explicit acceptance contract. Keep one owner per state; derived context snapshots retain their source identity. Retention within an experiment does not imply restart persistence.

## Maturity 1: Finite assessment / H (bounded slice implemented)

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

## Maturity 2: Experience influence (local, partial)

Remaining boundary: social positive/negative meaning, canonical history-dependent interpretation, sleep compression, forgetting and durable history. The broader acceptance goals below are not all met by current approach outcomes.

History storage and opt-in action influence are implemented: admitted Runtime approach decisions are matched to bounded Godot result reports, with source/subsequent observation IDs and agent/target/context separation. See [the Experience contract](../docs/experiment-contracts/EXPERIENCE_history_contract.md). Retention is 128 admitted decisions per process with no eviction. Social positive/negative relation semantics remain open; progress/no-progress does not establish them.

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

## Maturity 3: Local profiles / Body / Expression (partial)

Remaining boundary: DNA μ/σ → dynamic Neural Dynamics → derived sensitivity is design-only. Current fixed retry profiles are not neural-derived. The broader affect goals below are not claims of current psychological modeling.

Minimal derived response expression is now visible in Runtime Inspector:
engaged/holding/restricted/observing, with independent body/history factors and
source IDs. It is display-only; equal H can accompany different expressions.
See [the expression contract](../docs/experiment-contracts/EXPRESSION_response_contract.md).
Psychological affect, social relations and learned sensitivity remain open.

Minimal Body slice implemented: selected-agent movement capability is owned by
Godot, projected as a self snapshot, and applied to action eligibility and world
resolution. Full/limited/stopped controls and recovery are tested over real HTTP.
See [the Body contract](../docs/experiment-contracts/BODY_movement_contract.md).
This is an intervention experiment, not injury/fatigue dynamics or affect.

Minimal fixed response-profile slice implemented: per-agent short/standard/long retry windows (1/3/5 ticks), immutable within a run. Same-history/same-observation comparisons establish a local action difference; actual Godot verifies short-profile retry after one tick. See [the profile contract](../docs/experiment-contracts/SENSITIVITY_retry_profile_contract.md). Multi-dimensional sensitivity, biological body dynamics, psychological affect, learned updates, and social history remain open; the bounded Body and display-expression slices above are implemented.

Goal:
- separate sensitivity from learned history and derive visible affect as a GameAI-local layer;
- connect Neural Dynamics with Experience, Body, and Current Context without turning the layer map into a Core ontology.

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

## Maturity 4: M_Δ / T1 reconstruction (unimplemented)

Entry prerequisite: cross-layer separation acceptance and an explicit finite θ / M_Δ experiment contract. Do not promote local layer state into M_B by identity. SPEC v2.4 resolution and the current T1 Probe signature are recorded in the [semantic reference](../docs/semantic-reference/RDL_Core_T0_T1_reference.md); configurable ρ_B is not implemented.

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

## Maturity 5: Finite-context authority / fresh re-entry (unimplemented)

Goal:
- activate reconstructed `M_B'` only inside the finite context supported by evidence.

Acceptance:
- shadow/fresh re-entry evidence precedes cutover;
- authority is scoped by B / Purpose / selected conditions;
- one context is not silently generalized to another;
- outside migrated contexts previous behavior remains available until separately reviewed.

## Maturity 6: Richness / long-run behavior (acceptance open)

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
