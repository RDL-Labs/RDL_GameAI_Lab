# Finite Sleep Experience Window Contract

**Status:** S1 operational reference  
**Scope:** GameAI-local immutable source selection only

## Purpose

An explicitly enabled Sleep consolidation experiment may freeze a bounded set
of accepted raw Experience records for one agent and one sleep cycle.

```text
accepted raw Experience
-> same-agent filter
-> latest 3..6 eligible records
-> immutable source-reference window
```

Fewer than three records produces `INSUFFICIENT_EVIDENCE`. It does not produce
an empty cluster or relation candidate.

## Boundary

- Formation is opt-in and selects at most six completed records.
- Pending decisions are not Experience sources.
- Agent identities are never mixed.
- A formed `(agent_id, sleep_cycle)` window is replayed unchanged when later
  Experience arrives.
- Every source ID must remain traceable; disappearance or agent reassignment is
  rejected.
- The store does not mutate raw Experience.
- S1 creates no profile, cluster, relation candidate, action influence,
  canonical `M_B` admission, `H`, or `T1` process.

## Authority

```text
Sleep action != Sleep window
Sleep window != relation candidate
Sleep window != canonical M_B
Sleep window != T1
```
