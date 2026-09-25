# T1 Reconstruction Contract

**Status:** T1-C finite inactive reconstruction operational

## Purpose

T1-C constructs a new immutable `M_B'` artifact from one frozen T1-A bundle and
the latest complete T1-B selection, without mutating or replacing the old
`M_B`.

```text
retained current M_B
+ retained CandidateRelation
+ retained material provenance
-> distinct M_B' identity
-> RECONSTRUCTED_INACTIVE
```

## Reconstruction rule

The current `M_B` must be explicitly `RETAIN`. At least one
`CandidateRelation` must also be `RETAIN`. The v1 reconstruction copies the
finite boundary, coefficients, biases, and `xi_status` from the parent model.
It adopts only the finite relation signature of retained candidates.

RIB history, unresolved residual, and Experience may remain retained source
materials, but are not converted directly into relations or update vectors.
Rejected and deferred materials are not adopted.

## Identity and provenance

The artifact retains a new model ref, parent model ref, agent, source bundle,
selection ID/revision, retained material references, adopted relation source,
selection basis/evidence, and reconstructor version. Exact replay is
idempotent. The finite store holds at most 128 artifacts without eviction.

## Separation

```text
M_B' artifact != active M_B
reconstruction != authority cutover
reconstruction != re-entry
adopted relation != action rule
```

T1-C does not insert `M_B'` into the active model registry, resolve `M_delta`,
re-enter normal operation, reinterpret previous observations, or influence
Runtime action.

## p5 projection

p5 displays the latest reconstruction status from the canonical GET snapshot.
It cannot reconstruct or activate an artifact.

## Acceptance

1. Parent and at least one candidate require explicit RETAIN.
2. New and parent model identities differ.
3. Parent model remains byte-for-byte unchanged and active registry is unchanged.
4. Only retained candidates become adopted relations.
5. Rejected/deferred Experience is not converted into a relation.
6. Exact replay is idempotent; `M_delta` remains active and re-entry absent.
