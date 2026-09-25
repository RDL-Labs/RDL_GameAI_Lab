# Core 3270982 Authority Synchronization Contract

**Status:** C1 semantic synchronization complete; no new Runtime authority

**Pinned Core:** `RDL_Core@327098256a29e3f82f2a8649a6ec0202fd68a6c4`

## Purpose

This contract translates the current Core SILN / dynamic `theta` explanation
into GameAI ownership boundaries before C2-C4 implementation.

It does not implement `theta_eff`, enter `M_delta`, run T1, reconstruct `M_B'`,
or grant action authority.

## Core Chain

```text
SILN in a nonlinear relational network
-> finite B
-> self-side M_B + interaction-side RIB_B, both with xi
-> F
-> later changed interaction conditions
-> RIB_B'
-> F' under the same pre-update M_B
-> E
-> explicit finite review
-> unresolved residual H
-> compare H with theta or an explicitly evaluated theta_eff
```

```text
H < theta_eff  -> maintain / bounded local update
H >= theta_eff -> enter M_delta
```

Crossing the boundary authorizes entry to a reorganization phase only. It is
not a reconstruction result and does not make `H` an update vector.

## SILN and History

SILN is not an intrinsically linear object. It is a finite structure whose
response bias remains locally approximable under the current `B`, resolution,
conditions, relations, and history. History may be read as formation history
compressed into current relational constraints.

Therefore:

```text
raw Experience History != SILN
raw Experience History != M_B
Sleep CandidateRelation != current structural constraint by identity
Fast retrieval != structural adoption
```

GameAI History and candidates may become finite T1 materials later, but only
through explicit inspection and selection.

## Dynamic theta

`theta_eff` is not a new Core Primitive. It is an optional effective section of
the Core decision boundary when a fixed `theta` is insufficient.

```text
theta_eff(t) = finite evaluation of the current retention boundary
               under declared relation conditions
```

Possible declared inputs include the current frozen `M_B`, `B`, selected
interaction/support/constraint relations, and bounded history provenance.
Their owner modules are sources; none is `theta_eff` by identity.

```text
BodyState != theta_eff
SensitivityProfile != theta_eff
RestNeed / FoodNeed != theta_eff
candidate score != theta_eff
H != theta_eff
```

`theta_eff` may rise or fall while `H` stays fixed. `H` may change while the
boundary stays fixed. Their values, revisions, evaluation boundary, source
relations, and evaluator version must therefore be stored separately.

## xi Boundary

Every finite `M_B` and `RIB_B` retains `xi`. In GameAI, `xi` is not a missing
field count, uncertainty score, novelty value, unresolved list, cache miss, or
unknown World truth. No finite Engine snapshot or deterministic replay removes
it.

## Existing GameAI Mapping

| GameAI object | Current role | Explicit non-role |
|---|---|---|
| Godot World state | bounded experiment reference and interaction resolver | SILN truth or canonical `M_B` |
| observation packet | acquisition evidence | `RIB_B` by identity |
| canonical sidecar | finite `RIB_B`, frozen comparison, `E`, review, `H` diagnostic path | `theta_eff`, `M_delta`, T1 |
| raw Experience | accepted action-result history | `H`, `M_B`, commitment |
| Sleep candidate | sourced finite restructuring material | `E`, `H`, active relation |
| Fast retrieval | read-only rediscovery | review or adoption |
| p5 Workbench | read-only projection | semantic or mutation authority |

## Phase Ownership

```text
C2 owns: RIB_B/RIB_B' -> F/F' -> E -> explicit review -> H separation
C3 owns: finite theta_eff evaluation and H/theta comparison
C4 owns: normal-state versus M_delta transition
T1 owns: material expansion, inspection, retain/reject/defer, reconstruction
```

C1 forbids later phases from being silently implemented inside a candidate,
retrieval score, UI label, or action policy.

## Acceptance

1. Core source and commit are pinned.
2. `theta_eff` remains an optional effective boundary, not a new Primitive.
3. `H`, `theta_eff`, `M_delta`, and `M_B'` remain distinct objects/states.
4. Experience/candidate paths remain separate from canonical review.
5. `xi` is retained without being converted into a scalar proxy.
6. C2-C4 and T1 ownership are explicit before implementation begins.
