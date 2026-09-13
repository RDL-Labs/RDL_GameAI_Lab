# Experiment Roadmap

This roadmap follows the lab's current T0/T1 semantic baseline and the design discipline documented in `docs/design/RDL_GameAI_設計手法_DRAFT_v0.1.md`.

Each phase is accepted by bounded evidence, not by feature count.

## P0: T0/T1 Semantic Sync

Goal:
- Freeze the current GameAI meanings of `EFP`, `M_B`, `F/F'`, `E`, `H`, `ξ`, and T1 reconstruction against `Aporapeiron/RDL_Core`.

Acceptance:
- `EFP` is treated as a bounded section of interaction, not a permanently independent exogenous input.
- `F` and `F'` use the same pre-update `M_B`.
- affect labels do not directly add system `H`.
- `ξ` is not removed by deterministic replay or full engine snapshots.

## P1: Bounded Perception

Goal:
- Build the smallest agent that acts from bounded perception rather than engine reference state.

Acceptance:
- agent action selection does not directly read the complete engine-side world state.
- perception boundary and relevant context are recoverable in logs.

## P2: Interaction Loop

Goal:
- Establish one complete action-to-subsequent-observation loop.

```text
EFP
→ F
→ action
→ world / relation changes
→ EFP'
```

Acceptance:
- the agent's action measurably changes conditions generating later `EFP'`.
- the later observation is not fabricated as an independent fixture when interaction should determine it.

## P3: F / F' and E

Goal:
- Compare current prediction / interpretation with a subsequent action-section.

Acceptance:
- `F` and `F'` are interpreted with an identical frozen pre-update `M_B`.
- `E` is the discrepancy between those interpreted states, not engine truth minus agent representation.

## P4: Unresolved Residual to H

Goal:
- Route only unresolved discrepancy into `H`.

Acceptance:
- resolved discrepancy does not remain as system heat.
- `fear`, `fun`, `jealousy`, `anger`, `stress`, or static conflict cannot directly increment `H`.
- heat provenance remains inspectable enough to know what unresolved relation produced it.

## P5: Relation History

Goal:
- Make prior interaction history change present interpretation and action.

Acceptance:
- the same present event can produce different interpretation or behavior after different prior histories.
- strong positive and negative relational histories may coexist instead of collapsing into one scalar affinity.

Experiential check:

> **同じNPCを数日眺めたとき、「こいつ昨日のこと引きずってるな」と感じられるか。**

## P6: Individual Sensitivity

Goal:
- Separate temperament-like sensitivity from learned history.

Initial candidates:

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
stability_preference
control_loss_sensitivity
```

Acceptance:
- the same history and present context can yield different reactions across different sensitivity profiles.
- sensitivity is not treated as personality, relation strength, or H itself.

## P7: Affect Expression

Goal:
- Derive visible affect from interaction history rather than direct mood meters.

```text
H provenance
+ relation history
+ relation constraint
+ sensitivity profile
+ body state
+ current context
→ AffectExpression / ActionBias / DialogueTone
```

Acceptance:
- fear / fun / sulking / reassurance can differ despite similar total H.
- mixed states such as `怖いけど楽しい` remain possible.
- visible affect remains a derived GameAI layer, not a T0 primitive.

## P8: T1 Reconstruction

Goal:
- Let selected experience change later interpretation without forcing global overwrite.

```text
Probe
→ Expansion
→ Inspection
→ Selection
→ Reconstruction
```

Acceptance:
- at least one learned relation changes later behavior.
- contextual coexistence is possible when supported by history.
- reconstructed `M_B'` remains finite and does not erase `ξ`.

Example target:

```text
forest + daytime + trusted companion → enjoyable
forest + night + alone               → alert / avoid
```

## P9: Richness / Interestingness Observation

Goal:
- Evaluate whether history-dependent behavior becomes interesting without collapsing into a dominant optimal policy.

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
- no single survival or win scalar is used as the whole definition of success.
- observed diversity is not merely random behavior.

## Deferred Until a Break Requires Them

```text
Canary / Shadow / Promotion stack
advanced structure induction
large-scale long-horizon learning
advanced LLM dialogue
complex economy
reproduction
culture generation
```

These mechanisms may be introduced when an actual experiment break, provenance gap, or explicit question requires them.

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
