# T1 Material Expansion Contract

**Status:** T1-A finite material expansion operational

## Purpose

T1-A explicitly freezes inspectable materials for one active `M_delta`
transition. It does not inspect, select, adopt, or reconstruct them.

```text
active M_delta transition
-> current frozen M_B
-> RIB_B / RIB_B' history
-> transition-time unresolved residual
-> optional same-agent CandidateRelation
-> optional same-agent Experience
-> immutable material bundle
```

Every material begins with disposition `UNINSPECTED`.

## Admission boundary

Expansion requires matching model ref, assessment ID, agent ID, and transition
ID across the active `M_delta`, current frozen model, and C2 Review Path.
Normal phase cannot expand T1 materials.

Candidate and Experience inputs are finite and same-agent only:

```text
CandidateRelation <= 16
Experience <= 32
```

The bundle always includes four canonical materials: current `M_B`, both RIB
sections, and the transition-time unresolved residual. `H_vec` is frozen at
the C4 entry rather than reconstructed from a later review revision.

## Immutability

One deterministic bundle ID belongs to one transition. Exact replay returns the
existing bundle. Changed material input for the same transition is rejected.
The store retains at most 128 bundles and does not evict.

## Separation

```text
expanded material != retained material
expanded material != rejected material
expanded material != deferred material
CandidateRelation != adopted relation
material bundle != M_B'
```

T1-A does not run Probe, rank materials, assign retain/reject/defer, mutate the
old `M_B`, reconstruct `M_B'`, re-enter normal operation, or influence action.

## p5 projection

p5 reads bundle and material counts from the canonical GET snapshot. It has no
expansion or selection authority.

## Acceptance

1. Only active `M_delta` can expand.
2. Canonical and local materials retain type, identity, source, and payload.
3. Foreign-agent and duplicate local materials are rejected.
4. All materials remain `UNINSPECTED`.
5. Exact replay is idempotent; changed replay is rejected.
6. Snapshot access is read-only and T1-B/T1-C remain absent.
