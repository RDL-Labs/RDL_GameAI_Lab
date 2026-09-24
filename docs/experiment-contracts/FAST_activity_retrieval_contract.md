# Activity Fast Retrieval Contract

**Status:** F1 opt-in operational reference

## Purpose

```text
accepted current Experience
-> current derived Profile
-> L0 semantic relation-signature overlap
-> bounded top-k
-> L1 finite comparison
-> read-only retrieval snapshot
```

Enable this path with `--fast-retrieval`. Inspect it through
`GET /v1/fast-retrieval-snapshot` or the read-only p5 Workbench proxy.

## Identity Boundary

The existing `relation_id` includes its source Experience and is a
storage/provenance identity. F1 does not expect two Experiences to share that
ID. L0 uses the finite semantic signature `kind / predicate / object / status /
polarity / strength`. This signature is comparison material, not a global
relation identity or Truth.

## Bounds

- At most 32 catalog entries: the latest 29 raw Experience Profiles and at
  most three existing Sleep candidates.
- At most three returned matches.
- With `top_k >= 2`, retain the best eligible raw source and the best eligible
  Sleep candidate before filling remaining slots by global rank. Scores are not
  modified by this source-aware visibility rule.
- L0 rejects zero-overlap entries before L1.
- Raw Experience and Sleep candidate sources retain distinct `source_type` and
  provenance.
- `coverage`, `conflict`, and `unresolved` remain separate from score.
- Query storage is process-local, finite, immutable on replay, and restart-cleared.

## Authority

```text
Fast Retrieval
!= CandidateRelation generation
!= Commitment
!= action authority
!= E / H
!= canonical M_B
!= T1
```

F1 performs no clustering, common-relation extraction, multi-hop search, or
action influence. p5 only displays Runtime snapshots and keeps its mutation
proxy disabled.

## Acceptance

1. L0 and L1 are explicit and deterministic.
2. top-k and catalog size are finite.
3. raw Experience and Sleep candidates are distinguishable.
4. source and current Profile inputs remain unchanged.
5. the same observation/action policy result is unchanged by retrieval.
6. a complete source chain is available to the Inspector snapshot.
