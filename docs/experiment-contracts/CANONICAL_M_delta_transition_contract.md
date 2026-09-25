# Canonical M_delta Transition Contract

**Status:** C4 finite phase transition operational

## Purpose

C4 consumes the explicit C3 boundary result and separates normal maintenance
from entry into the `M_delta` reorganization phase.

```text
explicit review accepted
-> C3 evaluates H against theta_eff
-> maintain               : phase remains normal
-> rupture_boundary_met   : enter M_delta once
```

The transition occurs during accepted explicit review. Read-only snapshot or
GET operations never create a transition.

## State identity and retention

State is retained per frozen `model_ref`. An `M_delta` entry records the source
assessment and review revision, independent `H` and `theta_eff`, theta revision,
evaluator version, exact transition rule, and deterministic transition ID.

Once entered, `M_delta` remains active until a future explicit T1 resolution.
A later review cannot silently restore normal operation. The finite v1 store
holds at most 128 model states and rejects new states at capacity without
eviction.

## Separation

```text
rupture_boundary_met -> M_delta entry

M_delta != H
M_delta != theta_eff
M_delta != CandidateRelation
M_delta != T1 material selection
M_delta != M_B'
```

C4 does not expand candidate or history materials, run Probe, retain/reject/
defer materials, reconstruct `M_B'`, cut over authority, re-enter normal
operation, or alter Runtime actions.

## p5 projection

p5 reads `canonical_snapshot.M_delta` through the existing GET-only endpoint
and displays the latest phase. It cannot trigger or resolve the transition.

## Acceptance

1. `H < theta_eff` retains a normal state.
2. `H >= theta_eff` enters `M_delta` exactly once.
3. Snapshot/GET operations do not mutate phase state.
4. An active `M_delta` is not silently released by reassessment.
5. Entry provenance retains assessment, review, H, theta, and evaluator identity.
6. T1, `M_B'`, re-entry, and action authority remain absent.
