# B1c actual harvest -> Sleep -> subsequent interpretation

Code `87bf372`, baseline `6632c7c`.
[Cloud run 38254442469](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38254442469)
completed successfully on Ubuntu24.04 / Julia1.13.1. Native boundaries25 PASS,
continuous living12 PASS, total37. Two existing scenes, disabled/enabled,
three continuous days and three agents each. See [contract](contract.md).

## Result

| Scene / agent | Retained actual attempts | First Sleep result | Later result | Known predictions |
|---|---:|---|---|---:|
| shared A | 4 | INSUFFICIENT_EVIDENCE | same | 0 |
| shared B | 5 | REJECT | PREVIOUSLY_REJECTED | 0 |
| shared C | 5 | REJECT | PREVIOUSLY_REJECTED | 0 |
| sparse A | 6 | LOCAL_ADOPTED | MODEL_ALREADY_PRESENT | 0 |
| sparse B | 6 eventually | INSUFFICIENT_EVIDENCE | LOCAL_ADOPTED on night2 | 20 |
| sparse C | 6 | LOCAL_ADOPTED | MODEL_ALREADY_PRESENT | 0 |

Sparse B's first known prediction is at34,869 simulation seconds (third day),
after formation at31,680 seconds. A/C formed at14,400 seconds but did not
encounter the model's current near-affordance condition afterward. Model presence
is therefore distinct from actual applicability. Twenty predictions are twenty
observations, not twenty successful validations or new supporting experiences.
No accuracy claim is made from this count; later prediction-error evaluation is
not added in this step.

Shared B's fourth attempt actually failed; C's fifth failed. Loss of subsequent
observed affordance is also retained. These operations are not removed to build
a successful subset. A lacks five attempts and remains insufficient rather than
being declared validated or rejected from a smaller set.

## What changed

The living adapter pairs actual accepted pickup outcomes with a pre-action and
the next real observation. The earliest six records survive day changes. A
frozen night window supplies first3 formation and next2 held-out validation.
Accepted completed rest triggers the finite inspector. An observed count change
is also required, following the existing Python inspector's input boundary.
Daytime evaluation subsequently returns known only with the same near observed
affordance; far or absent affordance remains unknown.

The scaffold now labels visible food appearance explicitly. Its fixed resource
apparatus defaults to brown_capped_ovoid. This is not newly learned food identity,
general visual recognition, full OBS coverage, or knowledge of stock/site truth.

LOCAL_ADOPTED deliberately differs from canonical ADOPTED. The canonical
assessment/T1/reconstruction/cutover path remains unported, as does general
cross-action Sleep. The callback leaves previous empty-material Sleep behavior
available when this option is disabled.

## Preserved behavior and checks

Enabled/disabled operation counts and compact action transitions match in both
scenes. Downloaded results were additionally checked for identical final position,
body, inventory, private stock, distance, routes, social and aid states. All
three nights complete; day starts preserve previous terminal state; per-agent
record ownership/distinct operations and food conservation hold.

Sparse final ground31 + stock63 + consumed6 = initial100; shared ground0 +
stock10 + consumed6 = initial16. This adds learning materials and interpretation,
not a new action-selection rule or an improvement in gathering.

Native tests cover replay/conflict, foreign/unaccepted results, disjoint
formation/validation, held-out failure, incomplete and missing-count conditions,
insufficient evidence, no premature model use, absent affordance, frozen copies,
Sleep completion replay and safety interruption. The full repository suite and
long-duration benchmarks were not rerun. Saved artifacts include specs, code
hashes, compact results and test stdout. The59.9s integration test timing is not
a Python/Julia performance comparison.

## Next boundary

The learned interpretation can now be inspected during the following day.
Next, define its bounded contribution to existing movement candidates separately
from physical feasibility, direct goal priority and route support. Compare that
use-rule enabled/disabled; do not equate model formation with useful action change.
