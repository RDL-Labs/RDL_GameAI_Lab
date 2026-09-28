# L15A — adopted M_B contribution to the current movement field

Status: finite opt-in implementation. Acceptance results belong to the separate Evidence.
Baseline: `49c4806`. Core reference remains `86a0d4f3`.

## What is being connected

The current continuous landmark-return campaign remains the main execution path.
No new parallel agent hierarchy is introduced. Its existing adopted harvest relation
can contribute a bounded directional term before steering. `off` preserves legacy
behavior/output; `disabled` calculates the proposed contribution without applying it;
`enabled` applies it. Mode is immutable and checked against explicit World configuration.

| Material | Owner / meaning | Treatment in this slice |
|---|---|---|
| Current physical/obstacle observations | sensor + terrain calculator | Hard exclusions and missing data remain authoritative |
| Initial material teaching | sourced god-statue sample | Existing baseline food attraction; not learned M_B |
| Adopted harvest relation | PredictableResourceAgent + explicit 3/2 T1 admission | Additional finite approach-to-test appraisal |
| blocked/turn history | current controller | Existing priority/steering; not silently promoted to M_B |
| Night records | DayCycleAgent | Still no canonical Sleep admission |
| Other agents / SOC / NERV | their own experiments | No import into this field |

This is a concrete approximation of a self-side relation constraint field, not a new
Core definition or a claim that every M_B relation can be summed into one scalar.
M_B remains frozen within each observation's interpretation/selection. The field never
writes model, raw Experience, admission, or support counts.

## Prediction versus approach appraisal

Source relation: `l14b-harvest-affordance-persistence-v1`, formed from three actual pickup
operations and validated on two later unused operations. Five operations are not five
resource sites. Its existing prediction boundary remains reachable observed affordance.

New local projection purpose: `approach-to-test-observed-matching-appearance`.
Seeing the same coarse material appearance farther away is a **candidate opportunity to
test** that relation, not a known harvest result. The original interpreter is called with
actual current affordance; at distance it remains `unknown`. We do not forge a reachable
input, learn a new relation, identify a tree/source, or predict stock/navigation success.

The projection from an adopted relation to approach preference is a fixed GameAI-local
experimental rule. The gain is not itself learned. This separates learned evidence from
the chosen policy that uses it, and does not claim spontaneous invention of attraction.

## Finite calculation and provenance

- Only the current existing frontal food projection, maximum five observed items.
- Same run, agent, profile/revision, adopted candidate and exact relation signature.
- Explicit formation/validation operation references, with source times not in the future.
- Invalidated model, unavailable model, missing observation, incompatible profile or
  incomplete terrain contributes nothing; the reason remains explicit.
- Only already-scored directions. No blocked/no-surface/unknown direction is reopened.
- For each scored direction, take matching items' existing normalized proximity terms
  and multiply by `0.5 / 4`. Clamp the sum to `[-0.5, 0]`.
- This is an additional term, recorded separately from physical, obstacle and initial
  food contributions. Five directions, no global map, no unobserved World coordinates.
- Disabled mode records the same eligible proposal but leaves numerical terrain unchanged.

Trace: rule/mode, current observation, frozen model_ref, source candidate, 3/2 operation
references, current prediction status, per-direction value/current target refs, applied
status. Campaign decisions retain the field gate and actual final action/reason.

## Existing authority remains in charge

Projection occurs inside terrain construction before steering, including its current
geometry recheck. Confirmed-turn steps, heading persistence, reversal limits, pickup,
body correspondence, inventory, variation, landmark budgets, return and night retain their
existing authority. An eligible contribution does not guarantee a different action.

No extra observation, turn, move, goal budget, Sleep cycle or daily reset is granted.
Observation retry returns the original command; model projection never creates extra
Experience or causes another body operation. `off` must replay existing records exactly.

## Validation

Synthetic inputs must first produce an actual admitted model through the existing
Experience/T1 path. Compare disabled/enabled with identical observations/model/materials,
including a boundary geometry where final steering changes. Test no model, invalidation,
profile/observation mismatch, blocked geometry, foreign identity, future sources, snapshot
isolation, retry/concurrency, pickup/return/night priority and legacy regressions.

Real World: predeclared disabled/enabled, natural_meadow, A/B/C steady, three continuous
days each, 1× speed, same existing return/stop rules. No mid-run adjustment. Analyze logs
only after completion. This smoke comparison may produce no admitted models or no field
application; that is not evidence of learned movement improvement. Wall-clock timing and
run IDs differ, so this is not an exact counterfactual action comparison.

[Evidence](../experiment-evidence/LUANTI_L15A_model_movement_field_evidence.md): 142 related tests PASS, two 3-day World runs PASS; no real-World adopted-model effect observed.
