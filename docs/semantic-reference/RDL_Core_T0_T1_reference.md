# RDL_Core T0/T1 Semantic Reference

## Status

This document records the semantic reference used by `RDL_GameAI_Lab`.
It does not copy or replace the canonical RDL definitions.

Canonical source:

- Repository: `Aporapeiron/RDL_Core`
- T0 BASE: `00_T0_基盤層/T0 基底措定（BASE）.md`
- T0 SPEC: `00_T0_基盤層/T0 最低動作仕様（SPEC）.md`
- T1 overview: `01_T1_SILN操作層/T1_SILN操作_総論.md`
- T1 expansion: `01_T1_SILN操作層/T1_SILN展開.md`
- T1 inspection / selection: `01_T1_SILN操作層/T1_検査と選別.md`
- T1 reconstruction: `01_T1_SILN操作層/T1_再構成.md`

Reference state checked for this lab:

- BASE / SPEC: formal v2.1, interaction / action-section version
- T0 v2.1 promotion commit: `6e27275a1f6ce81fbaa47681f11a4a4a8b44231e`
- latest RDL_Core commit checked when this reference was written: `19c5eeca3f851abb428becd46c415e037a5c00d8`

If these references change, GameAI semantics should be rechecked rather than silently assuming compatibility.

---

## T0 invariants used by GameAI

### Interaction is foundational

GameAI does not treat one-way input as an independent foundational primitive.
An action or observation is an operational section cut from ongoing interaction by a finite Boundary, observation position, time section, and target direction.

```text
relation-network interaction
  ↓ finite B / observation position / time / target direction
EFP
```

### Finite Boundary always leaves unrecovered relation

```text
∀B_finite: ξ(B) ≠ 0
```

A deterministic engine, complete simulation snapshot, fixed seed, or replay trace may serve as a bounded experimental reference. None is promoted to terminal Truth or completeness.

### Engine state is not agent observation

```text
Engine world state / simulation reference
!= Agent Observation
!= Agent EFP
!= Agent M_B
```

The engine may expose a broader reference state for experiments while each agent remains bounded by its own observation and relation structure.

### EFP is an uninterpreted action bundle cut from interaction

```text
interaction
  ↓ Section_B(...)
EFP
  ↓ interp(M_B, EFP)
F
```

`EFP` does not have to be a simple independent exogenous input. A prior agent response may change the conditions generating the next `EFP'`.

```text
EFP_t
→ F_t
→ response / action
→ interaction conditions change
→ EFP_t+Δ
```

### F and F' use the same pre-update M_B

```text
F(t)    = interp(M_B, EFP(t))
F'(t+Δ) = interp(M_B, EFP(t+Δ))
E(t+Δ)  = Δ(F, F')
```

The comparison boundary must remain frozen until `E` is obtained.
Learning or reconstruction must not rewrite the comparison halfway through.

### H is unresolved inconsistency, not emotion

```text
E
↓ absorb / resolve under current M_B
unresolved residual
↓
H
```

Therefore:

```text
H != fear
H != fun
H != anger
H != jealousy
H != stress
```

Affect may be derived from the source of unresolved inconsistency, relation history, sensitivity profile, body state, and current context, but affect labels do not directly create system H.

### C10 remains active

If the current EFP section is insufficient, the conditions generating it may be re-targeted and inspected as interaction-derived structure.
The lab must not permanently freeze EFP as a simple exogenous input model.

---

## T1 operational method used by GameAI

T1 is used as the abstract formation / metabolism path for agent structures.

```text
Probe
→ Expansion
→ Inspection
→ Selection
→ Reconstruction
```

### Probe

Probe performs bounded contact with interaction and obtains differences available under the current Boundary.

```text
Probe_B(interaction) → {Δ}_B
with ξ' != 0
```

Probe does not retrieve or eliminate ξ itself.

### Expansion

Expansion opens a possibility space rather than collapsing immediately to one explanation or policy.
External theories, algorithms, psychology models, game-AI methods, simulation tools, and LLMs may be borrowed as expansion tools when useful.

### Inspection

Inspection applies tools such as replay, simulation, counterfactual reruns, canary trials, shadow evaluation, scenario tests, or statistical checks.

```text
Inspection tool != Selection criterion
```

### Selection

Selection criteria belong to the GameAI design Boundary.
The lab does not assume that winning, survival, or reward maximization is the sole criterion.
Possible criteria include history continuity, individual divergence, relational richness, readability, surprise, non-collapse into one dominant policy, and bounded safety.

```text
retain / reject / defer
```

`DEFER` is not the same as `REJECT`.

### Reconstruction

Selected relation structure can be incorporated into a later `M_B'`.
GameAI may use repair, phase-shift, or coexistence / parallel reconstruction.

Example:

```text
old:
  forest → enjoyable

new experience:
  attacked alone at night

avoid global overwrite:
  forest → dangerous

prefer contextual coexistence when supported:
  forest + daytime + trusted companion → enjoyable
  forest + night + alone               → alert / avoid
```

The reconstructed `M_B'` remains finite and continues to carry ξ.

---

## Responsibility split

```text
T0
  defines minimum semantic invariants

T1
  defines abstract formation / inspection / reconstruction process

T2 tools
  provide inspection and durability mechanisms

GameAI design
  defines sensors, body, world interface, Selection criteria,
  acceptable loss, interestingness dimensions, and experiment Boundary
```

`Selection != inspection tool` is a key constraint.

---

## Relationship to RDL_Enterprise

`RDL_Enterprise` is a reference implementation and design-method mine, not the canonical semantic source.
GameAI may reuse Enterprise mechanisms such as replay, canary, shadow, promotion, provenance, durability, and staged escalation only after translating them through the current T0/T1 boundary.

Useful Enterprise design invariants include:

```text
Observation != Candidate != Commitment != Active
UNKNOWN != UNRESOLVED != NOT_EVALUATED
Authority != Truth
same pre-update M_B for F / F'
Context / Provenance must recover semantic external conditions
bounded replay != world identity
test success != theory truth
```

---

## Review rule

When a new GameAI feature is proposed, check in this order:

```text
1. Does it violate T0 BASE / SPEC?
2. Does T1 already provide the formation / selection / reconstruction role?
3. Is the proposed mechanism only a tool or implementation detail?
4. What GameAI-specific Selection criterion justifies retaining it?
5. What finite acceptance evidence would establish operational sufficiency?
```

If the feature is not needed to resolve an observed break, recover provenance, or test a declared GameAI question, it may remain deferred.

---

## Non-claims

This reference does not claim that:

- the simulator engine state is world Truth;
- deterministic replay proves completeness;
- old `HState` / `HVec` implementations automatically satisfy T0 v2.1;
- RDL_Human hypotheses are foundational GameAI variables;
- Enterprise implementation names are normative RDL primitives;
- passing GameAI tests proves RDL itself.

This document is a bounded reference and should be revised when the canonical T0/T1 source or the GameAI Boundary changes.
