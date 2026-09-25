# Dynamic M_B Multi-Agent Regression Contract

**Status:** DMB-C two-agent regression complete

## Purpose

Verify that two agents can independently complete the full Dynamic `M_B` cycle
inside one Runtime sidecar without provenance, model, archive, phase, or window
leakage.

```text
Agent A: Experience -> candidate A -> rupture A -> T1 A -> M_B'A -> re-entry A
Agent B: Experience -> candidate B -> rupture B -> T1 B -> M_B'B -> re-entry B
```

## Required separation

- Every candidate and raw Experience entering T1-A belongs to the same agent as
  the active `M_delta` subject.
- Parent model refs, artifact refs, cutover refs, and archives remain distinct.
- Resolving one `M_delta` does not resolve the other.
- Each re-entry clears only that agent/context comparison window.
- Adopted relation provenance names only the corresponding agent's candidate.
- Canonical evaluator cutover does not change local game action decisions.

## Acceptance

1. Two active `M_delta` states exist before cutover.
2. Two independent cutovers produce two active reconstructed models.
3. Both parent models remain separately archived.
4. Both phases become REENTERED with active count zero.
5. First post-reentry observation for each agent produces no E.
6. Second observation produces E under that agent's new model ref.
7. Local action output remains identical before and after both cutovers.
