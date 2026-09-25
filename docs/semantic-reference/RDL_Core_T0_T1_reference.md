# RDL_Core T0/T1 Semantic Reference

## Status

This document records the semantic reference currently used by `RDL_GameAI_Lab`.
It does not copy or replace canonical RDL definitions.

Canonical source:

- Repository: `Aporapeiron/RDL_Core`
- T0 BASE: `00_T0_基盤層/T0 基底措定 (BASE).md`
- T0 SPEC: `00_T0_基盤層/T0最低動作仕様 (SPEC).md`
- T1: `01_T1_SILN操作層/`

Reference state checked for this lab:

- BASE: formal v2.3; SPEC: formal v2.4 (Standard Model resolution `ρ_B`)
- Core synchronization commit: `327098256a29e3f82f2a8649a6ec0202fd68a6c4`
- checked: 2026-09-25 against committed local sources
- [Pinned source tree](https://github.com/Aporapeiron/RDL_Core/tree/327098256a29e3f82f2a8649a6ec0202fd68a6c4)

Versions belong to individual documents, not uniformly to all T0/T1. Existing `v23_*` code and contract filenames remain compatibility names.

If canonical references change, GameAI semantics must be rechecked rather than silently assuming compatibility.

---

## T0 invariants used by GameAI

### SILN and interaction are prior to a one-way input model

GameAI does not promote engine packets or sensor payloads into an independent foundational input primitive.
A SILN participates in one or more relational interaction bundles `RIB`; the operational action side is cut from those interactions by a finite Boundary.

```text
nonlinear relational network
        ↕
      SILN
    ↕ RIB_i
        ↓ Purpose / finite B / observation position / time / target direction
      RIB_B
```

### Finite Boundary always leaves unrecovered relation

```text
∀B_finite: ξ(B) != 0
```

A deterministic engine, complete simulation snapshot, fixed seed, or replay trace may serve as a bounded experimental reference. None is promoted to terminal Truth or completeness.

`ξ` is not a runtime uncertainty score, missing-count metric, queue size, novelty scalar, or stress value.

### Engine state, observation, RIB_B, and M_B are distinct

```text
Engine world state / simulation reference
!= Agent Observation packet
!= canonical RIB_B
!= Agent M_B
```

The engine may expose a broad reference state for experiments while each agent remains bounded by its own observation and relation structure.

An observation packet is evidence available to an acquisition adapter. It becomes a canonical `RIB_B` only after a finite Purpose / B selects the relevant action-section, dimensions, conditions, coverage, and provenance.

```text
bounded observation packet
  ↓ acquisition under Purpose / finite B
RIB_B
```

Missing selected coverage must not be silently converted to zero.

### RIB_B is an uninterpreted finite action-section

```text
{RIB_i}
  ↓ Section_B(...)
RIB_B
  ↓ interp(M_B, RIB_B)
F
```

`RIB_B` is not required to be an independent exogenous input. A prior response may change the conditions generating later RIBs and therefore the next `RIB_B(t+Δ)`.

```text
RIB_B(t)
→ F(t)
→ response / action
→ interaction conditions change
→ later RIBs
→ RIB_B(t+Δ)
```

### F and F' use the same pre-update M_B

```text
F(t)    = interp(M_B, RIB_B(t))
F'(t+Δ) = interp(M_B, RIB_B(t+Δ))
E(t+Δ)  = Δ(F, F')
```

The comparison boundary must remain frozen until `E` is obtained. Learning or reconstruction must not rewrite the comparison halfway through.

### E is not world-truth error and is not automatically H

`E` is the discrepancy between the two interpretations formed under the same pre-update `M_B`.

```text
static structural conflict != E
engine truth - agent state != canonical E by definition
nonzero E != unresolved by definition
```

GameAI requires a finite assessment of whether a discrepancy is absorbed, explained, ordinary temporal change, boundary/coverage change, unresolved, or still pending before operationally routing anything into H.

### H is unresolved remainder, not emotion

```text
E
↓ current structure / bounded local absorption / finite assessment
unresolved remainder only
↓
H_vec
↓
H = ||H_vec||
```

The exact norm is implementation-local unless a specific experiment declares it.

Therefore:

```text
H != fear
H != fun
H != anger
H != jealousy
H != stress
H != Human Attention load
```

Affect may be derived from H provenance, relation history, sensitivity profile, body state, and current context, but affect labels do not directly create system H.

### H >= theta is only entry to M_delta

```text
H < theta  -> maintain / local update
H >= theta -> M_delta
```

`H` is not a direct update vector for `M_B'`. Once in `M_delta`, T1 owns the formation path.

### theta_eff is an optional relationally evaluated boundary

Core explanation `03_Explanation/06_動的θと関係配置.md` does not replace the
T0 definition of `theta` and does not add a new Primitive. It permits an
effective boundary when current relation conditions materially matter.

```text
theta_eff(t)
  = finite boundary evaluation under declared
    M_B / B / RIB and interaction conditions /
    support and constraint relations / history provenance
```

`H` and `theta_eff` can move independently. A fixed `H` can cross a falling
boundary, and added support can raise the boundary without resolving `H`.
GameAI must therefore retain separate values, revisions, inputs, and provenance.

```text
theta_eff != BodyState
theta_eff != SensitivityProfile
theta_eff != candidate score
H >= theta_eff != M_B' produced
```

The comparison only selects maintenance/local update versus entry to `M_delta`.
T1 still owns inspection, selection, and reconstruction.

---

## T1 reference method (not implemented in GameAI)

When `M_delta` is entered, current `M_B` becomes the finite self-side subject (`SILN_SELF`) for inspection and reconstruction.

```text
current M_B -> SILN_SELF
      ↓
Probe
→ Expansion
→ Inspection
→ Selection
→ Reconstruction
→ finite M_B'
→ fresh re-entry validation
```

### Probe

Probe performs bounded contact with interaction and obtains differences available under the current or explicitly changed finite Boundary.

```text
Probe_B(target, condition_k) → RIB_B^{probe,k}
F_k = interp(M_B, RIB_B^{probe,k})
{Δ}_B = Compare({RIB_B^{probe,k}}, {F_k}, prior)
with ξ'(B) != 0
```

Probe does not retrieve or eliminate ξ itself.

### Expansion

Expansion opens a possibility space rather than collapsing immediately to one explanation or policy. External theories, algorithms, psychology models, game-AI methods, simulation tools, and LLMs may be borrowed as finite-purpose tools.

### Inspection

Inspection may use replay, simulation, counterfactual reruns, canary trials, shadow evaluation, scenario tests, or statistical checks.

```text
Inspection tool != Selection criterion
```

### Selection

Selection criteria belong to the GameAI design Boundary. Winning, survival, or reward maximization is not assumed to be the sole criterion.

```text
retain / reject / defer
```

`DEFER` is not `REJECT`.

Possible GameAI criteria include history continuity, individual divergence, relational richness, readability, surprise, non-collapse into one dominant policy, and bounded safety.

### Reconstruction

Only retained relations may contribute to a later `M_B'`. A reconstruction proposal must preserve its finite valid conditions, break conditions, unresolved items, and provenance.

`M_B'` remains finite, revisable, and accompanied by ξ.

A fresh re-entry must observe new `RIB_B'` sections and revalidate the reconstructed structure rather than declaring terminal success.

---

## Operational resolution in SPEC v2.4

The Standard Model may declare relation-distinction granularity as `ρ_B` in `Section_B(... resolution = ρ_B, ...)`. Core Requirements are unchanged. Finer resolution does not guarantee larger E/H or eliminate ξ.

GameAI currently selects three visible-entity counts. Configurable `ρ_B` is not implemented; sensor radius, movement scale, and retry ticks are not relabeled as ρ. A future meaning-changing resolution selection must declare a comparison context/model boundary, not mutate the frozen F/F' window.

## Current GameAI adoption

Finite acquisition, frozen diagnostic interpretation, E, explicit residual review, retained H, finite `theta_eff`, explicit `M_delta` entry, T1 material processing, inactive reconstruction, canonical evaluator cutover, and fresh-window re-entry are operational. History, fixed sensitivity, body, derived expression, Sleep candidate formation, and Fast retrieval support separate local behavior/material paths. Game action authority remains local and is not transferred by evaluator cutover. This is not a claim that all T0 operation is implemented.

## Responsibility split

```text
T0
  minimum semantic invariants

T1
  formation / inspection / selection / reconstruction path

T2 tools
  durability and inspection mechanisms when needed

GameAI design
  sensors, body, world interface,
  Purpose / B acquisition rules,
  Selection criteria,
  acceptable loss,
  interestingness dimensions,
  experiment contracts
```

---

## Relationship to source mines

### RDL_Demos

`RDL_Demos` is a working implementation mine, not semantic authority. Its current Village v2.3 implementation is valuable because it now distinguishes canonical `RIB_B / E / H / M_delta / T1 / authority` from legacy-local `LocalLoadVector / ExplorationState / LeapEngine` mechanisms.

Legacy names such as `HVec`, `XiPool`, and `Boundary` must not be imported as Core meaning by name alone.

### RDL_Enterprise

`RDL_Enterprise` is a reference implementation and design-method mine. Its current v2.3 work is useful for bounded acquisition, provenance, same-frozen-`M_B` comparison, durable state, staged commitment, and live changed-condition acceptance.

Enterprise-local Human Attention, structural conflict, coverage metrics, and compatibility `*CompiledMB` names are not Core `H`, `E`, `ξ`, or `M_B` by identity.

### RDL_Human

`RDL_Human` is a T3 hypothesis mine. Current Human v2.3 documents explicitly separate Human-specific heat, SFO, self-boundary metaphors, cognitive-space variables, and other hypotheses from Core primitives.

---

## Review rule

When a new GameAI feature is proposed, check in this order:

```text
1. Does it violate pinned T0 BASE / SPEC (currently v2.3 / v2.4)?
2. Is raw observation being confused with RIB_B?
3. Does T1 already provide the formation / selection / reconstruction role?
4. Is the proposed mechanism only a tool or implementation detail?
5. What GameAI-specific Selection criterion justifies retaining it?
6. What finite acceptance evidence would establish operational sufficiency?
```

If a feature is not needed to resolve an observed break, recover provenance, or test a declared GameAI question, it may remain deferred.

---

## Non-claims

This reference does not claim that:

- simulator engine state is world Truth;
- an observation packet is automatically a canonical `RIB_B`;
- deterministic replay proves completeness;
- legacy `HState`, `HVec`, `XiPool`, or `LeapEngine` automatically satisfy current T0;
- RDL_Human hypotheses are foundational GameAI variables;
- Enterprise implementation names are normative RDL primitives;
- passing GameAI tests proves RDL itself.

This document is a bounded reference and must be revised when canonical T0/T1 or the GameAI Boundary changes.
