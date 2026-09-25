# Dynamic M_B Cutover and Re-entry Contract

**Status:** DMB-B finite canonical evaluator cutover operational

## Purpose

Explicitly activate one reconstructed inactive `M_B'`, preserve its parent,
resolve the matching `M_delta`, and begin a fresh comparison window.

```text
RECONSTRUCTED_INACTIVE M_B'
+ expected active parent model
+ active parent M_delta transition
+ explicit operator / basis / evidence
-> archive old M_B
-> activate M_B'
-> resolve M_delta as REENTERED
-> clear pre-update comparison window
```

## Atomic admission

Before mutation, cutover validates artifact status, unique active parent,
expected active model ref, matching agent/context, active parent `M_delta`, and
complete operator provenance. A new frozen evaluator is constructed first.
Capacity rejection or any validation failure leaves registry, archive, window,
and `M_delta` unchanged.

Exact replay is idempotent. Changed provenance for an already activated
artifact is rejected.

## Model continuity

The activated model keeps the reconstructed boundary, coefficients, biases,
`xi_status`, and adopted relation provenance. The parent moves unchanged to the
model archive. The new model receives a fresh comparison window: the first
post-reentry RIB forms no E, and only a later RIB under the same new model can
form F/F' and E.

## Separation

```text
canonical evaluator cutover != game action authority
REENTERED != old comparison resumed
archived M_B != deleted M_B
active M_B' != retrospective reinterpretation
```

DMB-B does not change decision policy, reinterpret earlier RIB sections, erase
Review/T1 provenance, or assert that the adopted relation is an action rule.

## p5 projection

p5 displays the latest cutover status from the existing GET-only canonical
snapshot. It cannot activate or re-enter a model.

## Acceptance

1. Only a valid inactive artifact with its active parent and M_delta can cut over.
2. Parent is archived unchanged and M_B' becomes the sole active context model.
3. M_delta becomes REENTERED and active count falls to zero.
4. Post-reentry comparison starts from a fresh first observation.
5. Exact replay is idempotent; changed provenance is rejected.
6. Runtime game action authority remains unchanged.
