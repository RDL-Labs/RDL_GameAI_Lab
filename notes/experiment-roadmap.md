# Experiment Roadmap

This roadmap follows the lab's current Core v2.3 semantic baseline and the design discipline documented in `docs/design/RDL_GameAI_設計手法_DRAFT_v0.1.md`.

Each phase is accepted by bounded evidence, not by feature count.

## P0: Core v2.3 / source-mine synchronization

Status: **DONE in current migration branch**

Goal:
- align GameAI terminology with `Aporapeiron/RDL_Core` BASE / SPEC v2.3;
- replace canonical `EFP` assumptions with `RIB / RIB_B`;
- re-evaluate Demos, Enterprise, and Human against their current main branches.

Acceptance:
- `Observation packet != RIB_B` is explicit;
- `RIB_B` is a finite section formed under Purpose / B;
- `F/F'` use the same pre-update `M_B` when later implemented;
- nonzero `E` does not automatically become `H`;
- `ξ` is not numericized;
- legacy Demos / Enterprise names are not imported as Core meaning by name alone.

## P1: Bounded Perception

Status: **ACCEPTED — retained as pre-canonical interaction evidence**

Goal:
- build the smallest agent that acts from bounded perception rather than engine reference state.

Contract:
- [P1 Bounded Perception Contract](../docs/experiment-contracts/P1_bounded_perception_contract.md)

Evidence:
- [P1 Bounded Perception Evidence](../docs/experiment-evidence/P1_bounded_perception_evidence.md)

Acceptance:
- action selection does not directly read complete engine-side world state;
- perception boundary and relevant context are recoverable in logs;
- bounded observation remains distinct from canonical `RIB_B`.

## P2: Actual Interaction Loop

Status: **ACCEPTED — retained**

Goal:
- establish one complete action-to-subsequent-observation loop.

Contract:
- [P2 Interaction Loop Contract](../docs/experiment-contracts/P2_interaction_loop_contract.md)

Evidence:
- [P2 Interaction Loop Evidence](../docs/experiment-evidence/P2_interaction_loop_evidence.md)

```text
bounded observation
→ runtime action
→ Godot world resolution / actual response
→ changed interaction conditions
→ subsequent bounded observation
```

Acceptance:
- action measurably changes interaction conditions;
- later bounded observation is generated after that change;
- source and subsequent observation instances are distinct;
- no `F/F'/E/H` is fabricated yet.

## P3: Canonical RIB_B Acquisition

Status: **IN PROGRESS / first read-only implementation added**

Goal:
- turn accepted bounded observation packets into explicit finite action-sections without treating the raw packet as Core `RIB_B` by identity.

```text
bounded observation packet
↓ acquisition adapter
Purpose / finite B
+ selected dimensions
+ conditions
+ coverage
+ provenance
↓
RIB_B
```

Current first selected dimensions:

```text
visible_agents_count
visible_objects_count
visible_places_count
```

These are demo-local selected dimensions, not Core-required GameAI variables.

Acceptance:
- raw observation packet and `RIB_B` remain distinct objects;
- finite Purpose / boundary id / selected dimensions / conditions are recoverable;
- selected missing coverage is not converted to zero;
- source observation id is preserved in provenance;
- `ξ` remains qualitative as `unrecovered-relations-remain` rather than a runtime scalar;
- sidecar capture cannot change the existing action decision;
- P3 does not create `M_B`, `F`, `F'`, `E`, `H`, `M_Δ`, or T1 state.

## P4: Frozen M_B / F / F' / E

Goal:
- introduce one explicit finite GameAI `M_B` evaluator and compare two actual canonical sections.

```text
RIB_B(t)
↓ same frozen pre-update M_B
F(t)

RIB_B(t+Δ)
↓ same frozen pre-update M_B
F'(t+Δ)
↓
E = Δ(F,F')
```

Acceptance:
- evaluator identity / version and interpretation conditions are frozen across the comparison;
- `E` is not engine-truth minus agent state;
- boundary or coverage drift prevents invalid comparison;
- missing selected dimensions do not become zero.

## P5: Finite Assessment / Unresolved Residual / H

Goal:
- route only explicitly assessed unresolved discrepancy into operational H.

Acceptance:
- `zero`, `pending`, `resolved`, `ordinary temporal change`, `boundary/coverage change`, and `unresolved` remain distinguishable;
- nonzero E alone is insufficient for H;
- only unresolved dimensions enter `H_vec`;
- `H = ||H_vec||` uses an explicitly declared demo-local norm;
- fear/fun/jealousy/stress/Human Attention/static conflict cannot directly increment H.

## P6: Relation History

Goal:
- make prior interaction history change present interpretation and action.

Acceptance:
- the same present event can produce different interpretation or behavior after different prior histories;
- strong positive and negative relational histories may coexist instead of collapsing into one scalar affinity.

Experiential check:

> **同じNPCを数日眺めたとき、「こいつ昨日のこと引きずってるな」と感じられるか。**

## P7: Individual Sensitivity and Affect Expression

Goal:
- separate temperament-like sensitivity from learned history and derive visible affect from finite interaction history.

Initial local candidates:

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
stability_preference
control_loss_sensitivity
```

Acceptance:
- same history and context can yield different behavior across profiles;
- sensitivity is not personality, relation strength, Core H, or Core ξ;
- visible affect remains derived, not a T0 primitive;
- similar total H may yield different affect because provenance/history/context differ.

## P8: M_Δ / T1 Reconstruction

Goal:
- let selected experience change later interpretation without forcing global overwrite.

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
- H is only the entry condition, not the reconstruction update vector;
- Selection distinguishes `retain / reject / defer`;
- retained relation, valid conditions, break conditions, unresolved items, and provenance are explicit;
- reconstructed `M_B'` remains finite and does not erase ξ.

## P9: Finite-context Authority / Fresh Re-entry

Goal:
- activate a reconstructed `M_B'` only inside the finite context supported by evidence.

Acceptance:
- shadow / fresh re-entry evidence precedes authority cutover;
- authority is scoped by finite B / Purpose / relevant conditions;
- reconstruction in one context is not silently generalized to another;
- outside migrated contexts, previous behavior remains available until separately reviewed.

## P10: Richness / Long-run Behavior

Goal:
- evaluate whether history-dependent behavior becomes interesting without collapsing into a dominant optimal policy.

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
- no single survival or win scalar defines success;
- observed diversity is not merely random behavior;
- long-run behavior remains inspectable through finite provenance.

## Deferred Until a Break Requires Them

```text
large-scale Canary / Shadow / Promotion stack
Human Attention workflow
advanced structure induction
large-scale long-horizon learning
advanced LLM dialogue
complex economy
reproduction
culture generation
```

Existing Enterprise / Demos mechanisms may be introduced when a concrete break, provenance gap, or explicit GameAI question requires them.

## Stop Rule

A phase may be stopped when it is:

```text
current finite Boundaryで operationally sufficient
```

This does not mean:

```text
terminally complete
universally valid
all NPC behavior evaluated
RDL theory proven
```

Reopen a phase when a concrete scenario breaks the current contract, a new operational requirement appears, or the current Boundary cannot reconstruct an observed transition.
