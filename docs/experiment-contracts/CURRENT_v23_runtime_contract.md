# Current Core v2.3 Runtime Contract

This document is the current operational contract for `RDL_GameAI_Lab`.
It replaces the older phase-specific contracts as the active reference.

## Current finite path

```text
engine/world reference state
  != agent bounded observation

agent bounded observation
  -> existing action decision
  -> Godot world resolution
  -> changed interaction conditions
  -> subsequent bounded observation

accepted bounded observation
  -> explicit Purpose / finite B / selected dimensions / conditions / coverage / provenance
  -> RIB_B

RIB_B(t)
  -> same frozen pre-update M_B
  -> F(t)

RIB_B(t+Δ)
  -> same frozen pre-update M_B
  -> F'(t+Δ)
  -> E = Δ(F,F')
```

## Required separations

```text
Engine reference state != Agent observation
Agent observation       != RIB_B
RIB_B                   != F
M_B                     != action policy by identity
E                       != engine truth minus agent state
E                       != H
ξ                       != missing count / noise / coverage scalar
```

The current canonical sidecar is read-only. It cannot change the existing action response.

## Finite B

The current first boundary is intentionally small:

```text
Purpose: bounded-action-context
selected dimensions:
  visible_agents_count
  visible_objects_count
  visible_places_count
conditions:
  observation packet schema
  perception rule
```

The selected dimensions are GameAI-local experiment choices, not Core-required variables.

If selected coverage is missing, the canonical section is not formed. Missing values are not converted to zero. Boundary conditions and formed RIB_B mappings are immutable after formation.

## Frozen M_B

The runtime uses an explicit finite immutable diagnostic evaluator scoped to one exact:

```text
agent
+ boundary id
+ Purpose
+ selected dimensions
+ conditions
```

The first implementation uses an identity projection over the selected count dimensions so formation and comparison remain inspectable. This is a local experiment model, not a universal GameAI interpretation law and not action authority.

Changing the evaluator requires a new `model_ref` and therefore a new comparison window.

## F / F' / E

A valid comparison requires:

- same agent;
- same exact finite context;
- same complete selected coverage;
- same frozen pre-update `model_ref`;
- distinct observation instances;
- no M_B update between F and F'.

Reposting the same observation id does not manufacture a new F' comparison.

`E` is retained as a signed per-dimension delta between the two interpreted states. A separate explicit review may select unresolved residuals; raw E is never automatically aggregated into H.

## ξ

Every finite section remains open to unrecovered relation:

```text
xi_status = unrecovered-relations-remain
```

This is qualitative provenance. It is not a runtime numeric estimate of Core ξ.

## Current stop boundary

Implemented now:

```text
bounded observation
-> actual action / changed conditions / later observation
-> RIB_B acquisition
-> frozen M_B
-> F / F'
-> E
```

Not implemented yet:

```text
temporal H accumulation / θ
M_Δ
T1 reconstruction
finite-context authority cutover
```

Explicit finite assessment and single-comparison residual H are now implemented as a diagnostic path. Nonzero E alone never becomes H.

## Finite assessment API

`GET /v1/canonical-snapshot` includes `assessment.records`. Each record identifies the original E pair, frozen model and finite context. Zero dimensions start as `zero`; nonzero dimensions start as `pending`. H=0 before review means no admitted residual, not proof of resolution.

`POST /v1/assessment-review` accepts the following shape. Use an actual `assessment_id` and current revision from the snapshot, and review all selected dimensions:

```json
{
  "assessment_id": "<id from snapshot>",
  "expected_revision": 0,
  "reviewer": "local-experiment-reviewer",
  "basis": "<finite criterion and why the remainder is unresolved>",
  "evidence": "<fixture or observation evidence reference>",
  "dimensions": {
    "visible_agents_count": {"status": "zero"},
    "visible_objects_count": {"status": "unresolved", "residual": 1.0},
    "visible_places_count": {"status": "zero"}
  }
}
```

This example requires an E whose agents/places deltas are zero and whose object delta has magnitude at least 1. Review statuses are `zero`, `pending`, `resolved`, `ordinary_temporal_change`, `boundary_coverage_change`, `unresolved`. A boundary/coverage change that prevents E formation still remains an acquisition/comparison exclusion; the review status cannot manufacture a cross-context E.

Only `unresolved` has a positive residual, bounded by `abs(E_dimension)`. All other statuses contribute zero. `H_vec` retains these nonnegative magnitudes and `H = L2(H_vec)` within this single comparison. This is a GameAI-local model, with no temporal sum, decay, cancellation, θ, or reconstruction. Re-review replaces the current assessment atomically; resolving a dimension removes its residual. Stale revisions and incomplete/invalid reviews return 422 without changing state.

Reviewer/basis/evidence are declared provenance, not authenticated identity or automatic proof of semantic correctness. An experiment must supply its finite review criterion. Fear, fun, attention, and static conflict are not accepted dimensions. No autonomous unresolved classifier is claimed.

Retention: at most 128 comparison records per process. Capacity exhaustion preserves existing records and increments `capacity_rejections`; further E can still be observed but is not admitted for review. Repeated pair registration is idempotent. Snapshot exposes all retained contexts separately; there is no agent-wide H total. Restart clears the ledger; only the latest review/revision is retained, not a durable audit history.

The API is a localhost diagnostic control. Review/capture/snapshot operations are serialized by a shared lock. Neither review nor H changes the action response, Godot state, or frozen M_B. A review UI and persistent ledger remain future work.
