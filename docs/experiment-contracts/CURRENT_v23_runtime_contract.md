# Current Core v2.3 Runtime Contract

This document is the current operational contract for `RDL_GameAI_Lab`.
It replaces the old phase-specific P1/P2/P3 contracts as the active reference.

## Current finite path

```text
engine/world reference state
  != agent bounded observation

agent bounded observation
  -> existing action decision
  -> Godot world resolution
  -> changed interaction conditions
  -> subsequent bounded observation

accepted bounded observation
  -> explicit Purpose / finite B / selected dimensions / conditions / coverage / provenance
  -> RIB_B

RIB_B(t)
  -> same frozen pre-update M_B
  -> F(t)

RIB_B(t+Δ)
  -> same frozen pre-update M_B
  -> F'(t+Δ)
  -> E = Δ(F,F')
```

## Required separations

```text
Engine reference state != Agent observation
Agent observation       != RIB_B
RIB_B                   != F
M_B                     != action policy by identity
E                       != engine truth minus agent state
E                       != H
ξ                       != missing count / noise / coverage scalar
```

The current canonical sidecar is read-only. It cannot change the existing action response.

## Finite B

The current first boundary is intentionally small:

```text
Purpose: bounded-action-context
selected dimensions:
  visible_agents_count
  visible_objects_count
  visible_places_count
conditions:
  observation packet schema
  perception rule
```

The selected dimensions are GameAI-local experiment choices, not Core-required variables.

If selected coverage is missing, the canonical section is not formed. Missing values are not converted to zero.

## Frozen M_B

P4 uses an explicit finite immutable diagnostic evaluator scoped to one exact:

```text
agent
+ boundary id
+ Purpose
+ selected dimensions
+ conditions
```

The first implementation uses an identity projection over the selected count dimensions so formation and comparison remain inspectable. This is a local experiment model, not a universal GameAI interpretation law and not action authority.

Changing the evaluator requires a new `model_ref` and therefore a new comparison window.

## F / F' / E

A valid comparison requires:

- same agent;
- same exact finite context;
- same complete selected coverage;
- same frozen pre-update `model_ref`;
- no M_B update between F and F'.

`E` is retained as a signed per-dimension delta between the two interpreted states. The current runtime does not aggregate E into H.

## ξ

Every finite section remains open to unrecovered relation:

```text
xi_status = unrecovered-relations-remain
```

This is qualitative provenance. It is not a runtime numeric estimate of Core ξ.

## Current stop boundary

Implemented now:

```text
bounded observation
-> actual action / changed conditions / later observation
-> RIB_B acquisition
-> frozen M_B
-> F / F'
-> E
```

Not implemented yet:

```text
finite unresolved assessment
H_vec / H / θ
M_Δ
T1 reconstruction
finite-context authority cutover
```

The next semantic step is explicit finite assessment of E. Nonzero E alone must not become H.
