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
!= H established
```

The canonical path is read-only and does not yet own action/reconstruction authority.

## Next 1 — finite assessment / unresolved residual / H

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

## Next 2 — relation history

Goal:
- prior interaction history changes present interpretation and action.

Acceptance:
- the same present event can yield different interpretation/behavior after different finite histories;
- positive and negative relation histories may coexist;
- history is finite provenance, not complete world truth.

Experiential check:

> **同じNPCを数日眺めたとき、「こいつ昨日のこと引きずってるな」と感じられるか。**

## Next 3 — individual sensitivity / affect expression

Goal:
- separate sensitivity from learned history and derive visible affect as a GameAI-local layer.

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
- sensitivity is not personality, relation strength, Core H, or Core ξ;
- similar total H may yield different affect because provenance/history/context differ;
- visible affect remains derived rather than T0 primitive.

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
large-scale Canary / Shadow / Promotion stack
Human Attention workflow
advanced structure induction
large-scale long-horizon learning
advanced LLM dialogue
complex economy
reproduction
culture generation
```

## Global stop rule

A boundary may be considered operationally sufficient only inside its declared finite conditions.

```text
current finite Boundaryで operationally sufficient
!= terminally complete
!= universally valid
!= all NPC behavior evaluated
!= RDL theory proven
```
