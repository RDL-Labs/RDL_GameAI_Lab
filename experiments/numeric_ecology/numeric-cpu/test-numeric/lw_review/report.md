# B1e later outcome comparison and invalidation

Implementation65e99fc, baseline94a0371.
[Cloud run38260345159](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38260345159)
passed55 boundary assertions and10 continuous-living assertions (65 total).
Two scenes, enabled/disabled review, three continuous days, three agents each.
Julia1.13.1 on Ubuntu24.04. See [contract](contract.md).

## Natural later counterexamples

All three sparse-scene agents encountered comparable persistence differences:

| Agent | Confirmed predictions before difference | Difference comparison time | Final stock review off/on |
|---|---:|---:|---:|
| A | 11 | 35,059s | 23 / 38 |
| B | 5 | 34,688s | 20 / 27 |
| C | 5 | 17,728s | 39 / 17 |

Each actual pickup succeeded. Frozen F=(acquired1, affordance_persists1),
observed F_prime=(acquired1, affordance_persists0), difference=(0,-1).
The latter is the next real complete scaffold observation, not an injected
failure or lookup of remaining resource stock. It invalidates the conjunction's
current use, not the historical fact that food was acquired. Depletion or another
agent's activity are not inferred as causes from that difference alone.

The original model/admission remains saved with first invalidation evidence.
Subsequent predictions become unknown and movement field projection stops;
night3 reports MODEL_INVALIDATED for all three. Comparison journals carry21
confirmed and3 difference results in total, with no natural defer in these runs.
Incomplete/pose/unexecuted defer cases are native boundary tests, not World runs.

## Whole-living result

Both sparse conditions finish with ground12, private stock82, consumed6 and
carried0 (initial100). Actual ground acquisitions remain84. Individual allocation
changes significantly:23/20/39 becomes38/27/17. This is a shared-World result,
not independent per-agent effect estimation or evidence of improved efficiency.
Earlier C invalidation can change resources and observations later encountered
by others. Field counts before invalidation also differ with those trajectories.

All agents complete Sleep on three nights and finish within home contact. The
saved post-invalidation action transitions include further movement and living
actions; disabling a learned contribution does not disable the controller.
Daily continuity, operation counts and food conservation pass. Downloaded data
was additionally checked for terminal balances, comparison/model bindings and
chronological journals ending at first invalidation.

Shared camp remains unchanged (no adopted model, no later-model comparisons):
ground0, private stock10, consumed6, initial16.

## Implementation boundary

Freeze known prediction before pickup, pair it with the accepted operation and
next actual observation, then compare dimensions before the next selection.
Pose correspondence uses unchanged actual own position/yaw in this scaffold.
One comparable difference stops local model use, matching the existing Python
multi_resource_exploration rule. Unknown or incomplete information is not failure.
No new variation, recovery or relearning policy is introduced.

Immediate duplicate receipt is idempotent, conflicts/older results reject;
bounded32 diagnostic rows and cumulative counters avoid unbounded history.
Native tests verify source/model/actor binding, frozen source model, no repeated
receipt effect, field suppression and no Sleep resurrection. No canonical T1
reconstruction or Core H threshold update is claimed. Full-suite and long-duration
performance tests were not run. The67.2s living test is not a speed comparison.

The next boundary is what to do with the retained difference: narrow the context,
form a replacement candidate from later independent material, or continue with
initial control. The experiment currently stops at explicit invalidation; it does
not silently relearn from the same original five successes.
