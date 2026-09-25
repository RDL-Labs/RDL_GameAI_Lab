# T1 Material Selection Contract

**Status:** T1-B explicit material inspection operational

## Purpose

T1-B assigns one explicit disposition to every material in an immutable T1-A
bundle.

```text
UNINSPECTED material
-> explicit reviewer + basis + evidence
-> RETAIN | REJECT | DEFER
```

No disposition is inferred from material type, score, H, candidate support, or
World outcome. Review must cover every bundle material exactly once.

## Review record

Each result retains bundle, agent, model, transition, reviewer, revision, source
material identity/type, disposition, basis, and evidence. The ledger records
counts for all three dispositions.

A revision guard permits explicit reinspection. Invalid partial, duplicate,
unknown, or stale-revision input is rejected before changing the current record.
The ledger holds at most 128 bundle reviews without eviction.

## Separation

```text
RETAIN != adopted relation
REJECT != deletion from history
DEFER != silent omission
selection record != reconstruction
selection record != M_B'
```

T1-B does not mutate the T1-A bundle or old `M_B`, run reconstruction, resolve
`M_delta`, re-enter normal operation, or influence action.

## p5 projection

p5 displays the latest RETAIN/REJECT/DEFER counts through the existing GET-only
canonical snapshot. It cannot submit or revise inspection.

## Acceptance

1. Every material receives exactly one explicit disposition.
2. Partial, duplicate, unknown, and stale-revision reviews are rejected atomically.
3. Reinspection increments revision and retains new provenance.
4. RETAIN does not adopt a candidate or modify `M_B`.
5. Bundle, model, `M_delta`, and action behavior remain unchanged.
6. T1-C reconstruction and `M_B'` remain absent.
