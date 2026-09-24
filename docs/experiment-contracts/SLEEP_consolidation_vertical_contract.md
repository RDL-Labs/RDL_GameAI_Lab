# Sleep Consolidation Vertical Contract

**Status:** S4 opt-in operational reference

## Boundary

```text
accepted daytime Experience
-> explicit consolidation cycle
-> fixed S1 window
-> safe bounded Sleep action
-> S2 relation profiles
-> S3 Deep Similarity shadow
-> one sourced CandidateRelation
```

`--sleep-consolidation` enables this path. The cycle begins when Godot explicitly
enables consolidation. Runtime freezes the same-agent Experience window on the
first observation carrying that cycle ID, before approaches toward the Sleep
place can enter later history.

The completed Sleep result must match a registered `sleep` decision, agent,
source observation, safe reachable target, and cycle. Exact replay is
idempotent; conflicting replay is rejected.

## Insufficient Evidence

A successful Sleep action does not manufacture evidence. Fewer than three
accepted daytime Experience records produce `INSUFFICIENT_EVIDENCE`, with no
Deep Similarity result and no candidate.

## Authority

```text
CandidateRelation
!= action authority
!= E
!= H
!= theta_eff
!= M_delta
!= M_B'
!= T1
```

Consolidation does not mutate raw Experience, World state, the next action, or
canonical state. The result is an inspectable GameAI-local shadow only.

## Evidence

The real Godot/HTTP vertical creates three accepted daytime interactions,
starts one explicit cycle, reaches safe Plaza, reports bounded Sleep completion,
and forms one candidate sourced only from the frozen three-record window.
Ordinary Sleep remains `consolidation=not_run` when this opt-in is disabled.
