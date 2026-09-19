# Base-Food Result Causality Contract

**Status:** Phase A operational

## Admission Chain

A `replenish_success` result is admitted only when it binds to an already
frozen decision for the same agent and source observation:

```text
registered bounded decision
-> action = deposit
-> target = decision packet's known Base
-> goal = replenish_base_food
-> trajectory phase = DEPOSIT
-> cue_id = source packet cue provenance
-> replenish_success admission
```

An unknown observation, another agent's observation, a non-deposit action, a
non-Base target, a mismatched cue, or a conflicting result-ID replay is
rejected without mutation. A result payload cannot manufacture Experience by
itself.

## Replay

After basic finite payload validation, an exact replay returns a deep copy of
the existing record immediately. It does not write `_results` again and does
not call trajectory completion. Therefore replay cannot clear a later active
trajectory, increase habit count, or alter retained Experience.

This is GameAI-local causal admission. It does not grant canonical `M_B`, `H`,
T1, or action authority.
