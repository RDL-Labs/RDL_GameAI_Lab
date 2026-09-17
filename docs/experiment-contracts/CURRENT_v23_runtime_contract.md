# Current Runtime Contract

This document is the current operational contract for `RDL_GameAI_Lab`.
It replaces the older phase-specific contracts as the active reference.

Core reference: BASE v2.3 / SPEC v2.4 at `9c60c5b`; see the
[semantic reference](../semantic-reference/RDL_Core_T0_T1_reference.md).
The filename is retained for compatibility. Local behavior/display is covered by
the [cross-layer separation contract](CROSS_LAYER_separation_contract.md).

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
  -> explicit finite residual review
  -> H / retained H per exact context and frozen model
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

## Minimal Food action path

The first game-feature contract adds bounded `approach / pickup / eat`
selection while Godot retains world-resolution authority. FoodNeed and held
food are body snapshot fields and are not selected canonical count dimensions.
FoodNeed is semantically intended to participate in a future explicitly formed
M_B relation network, but it is not admitted to the current frozen count-sidecar
M_B. The owner body module is not M_B by identity.
History retry influence applies only to approach and cannot intercept pickup or
eat. See [the Food contract](FOOD_minimal_loop_contract.md).

An offline, default-off [FoodNeed shadow contract](FOOD_NEED_MB_shadow_contract.md)
now forms a separate finite relation and shadow F/F'/E for controlled tests. It
is not registered in this runtime's global canonical sidecar and has no bridge,
assessment, H, action, or Godot authority.

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
time decay / θ
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

Only `unresolved` has a positive residual, bounded by `abs(E_dimension)`. All other statuses contribute zero. Each record exposes these nonnegative magnitudes as `H_vec` and `H = L2(H_vec)` within the single comparison. Context-level retention is defined below. Re-review replaces the current assessment atomically; resolving a dimension removes its residual. Stale revisions and incomplete/invalid reviews return 422 without changing state.

Reviewer/basis/evidence are declared provenance, not authenticated identity or automatic proof of semantic correctness. An experiment must supply its finite review criterion. Fear, fun, attention, and static conflict are not accepted dimensions. No autonomous unresolved classifier is claimed.

Retention: at most 128 comparison records per process. Capacity exhaustion preserves existing records and increments `capacity_rejections`; further E can still be observed but is not admitted for review. Repeated pair registration is idempotent. Snapshot exposes all retained contexts separately; there is no agent-wide H total. Restart clears the ledger; only the latest review/revision is retained, not a durable audit history. The 128-case bound applies to the assessment ledger, not to all sidecar observation/model caches.

### Retained H across comparisons

`assessment.retained_H` groups records by exact finite context (including agent) and frozen `model_ref`. For every dimension, sum the unresolved residual magnitudes in the latest revision of each admitted comparison, then take the L2 norm of that vector. This is the explicit GameAI-local `Remain(H, dt) = H` baseline: elapsed ticks do not decay a residual; a later zero E does not clear earlier unresolved records.

Each comparison contributes once. Re-review replaces its contribution rather than adding a new one. Resolution removes the relevant contribution. Positive and negative E do not cancel because the selected model retains magnitudes. Every group exposes source assessment IDs/revisions, pending-dimension count, and comparison count. H=0 with pending items is not evidence of complete resolution. Capacity rejection means retained H covers only admitted cases. Numeric overflow is reported as unavailable (`H=null`, `status=numeric_overflow`), never as a finite result.

A reviewer must distinguish a new residual event from renewed evidence of an existing problem. Fresh observation IDs alone do not prove independent unresolved events: use `pending` or another non-residual classification when that is not established, or re-review the original case. No semantic event deduplication is claimed.

Within a context, already accepted observation IDs are ignored even after intervening observations; the first accepted instance owns the ID. A new observation with a regressing tick is rejected from canonical comparison. Distinct instances at the same tick remain valid. The current process is one observation-ID namespace: after resetting Godot tick/IDs, restart the runtime before beginning a new experiment. Automatic session/reset coordination remains deferred.

Retained H does not enable θ, M_Δ, action authority, cross-context transfer, or a general time-decay law.

The API is a localhost diagnostic control. Review/capture/snapshot operations are serialized by a shared lock. Neither review nor H changes the action response, Godot state, or frozen M_B. A review UI and persistent ledger remain future work.
