# Canonical Review Path Projection Contract

**Status:** C2 operational diagnostic projection

## Purpose

Expose each admitted canonical diagnostic comparison as one inspectable chain:

```text
RIB_B -> F
RIB_B' -> F'
same frozen pre-update M_B
-> E
-> explicit finite review
-> H_vec / H
```

The projection reuses existing acquisition, interpretation, comparison, and
assessment results. It does not recompute them and does not classify a pending
dimension automatically.

## Identity and Retention

Each path is keyed by its finite `assessment_id`. The sidecar retains the first
and later sections and interpretations only when the assessment ledger admits
the comparison. The existing 128-record assessment capacity therefore remains
the projection bound.

Review updates replace the projected review revision and `H` view without
changing the retained `RIB_B/F/F'/E` pair.

## Separation

```text
raw Experience != review input
Sleep CandidateRelation != E or H
Fast retrieval != explicit review
p5 projection != review authority
```

The projection explicitly excludes raw Experience, Sleep candidate, and Fast
retrieval sources. Those may become later T1 materials, but cannot enter C2 by
being present or retrieved.

```text
nonzero E != H
pending review with H=0 != resolved
reviewed unresolved residual -> H
H != theta_eff
H != M_delta
```

## p5 Boundary

p5 reads `canonical_snapshot.review_path` through the existing GET-only proxy.
It displays path count, latest review status/revision, nonzero E dimension count,
and H. It cannot submit a review or mutate Runtime state.

## Acceptance

1. Both section and interpretation instances remain traceable.
2. `F/F'` retain the same frozen `model_ref`.
3. E remains pending until explicit review.
4. Review revision and admitted residual H are visible together.
5. Candidate/retrieval activity cannot change the projection.
6. `theta_eff`, `M_delta`, T1, and action authority remain absent.
