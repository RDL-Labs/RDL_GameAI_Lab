# B1b observed landmarks and routes

Finite LW reconnection, not full navigator reproduction. Implementation `1b0621a`,
observation-reference correction `5fa04c7`. Baseline B1a `afc747f`.

Initial cloud run [38251323641](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38251323641)
passed 27 native boundary assertions and 12 living integration assertions.
Ubuntu Julia 1.13.1; two scenes, disabled/enabled, three continuous days each,
three agents. No new campfire, behavioral coefficients fitted to outcomes, or
Python full-trace equality gate. See [contract](contract.md).

Final-code run [38251973682](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38251973682)
at `5fa04c7` also passed all39 assertions. Its saved report.json equals the
initial run's output. The correction binds a candidate's diagnostic observation
reference to the observation ID rather than its operation ID; decisions are
unchanged. Artifacts contain specs, source hashes, stdout and compact results.

## What is connected

The existing LW horizontal fan is sampled with 13 rays and compared against six
actual Python World.cast fixtures. Policy receives color, angular interval and
coarse range only. Currently observed unambiguous landmarks can supply feasible
movement candidates. Actual walking records finite color sequences. Depositing
the same actually picked-up cargo can support a route; its reverse is initially
an unsupported proposal. Current visibility and physical feasibility remain
necessary. Route support and blocked H affect candidate strength.

Inventory provenance follows pickup, consumption, transfer and deposit. Giving
or consuming the original pickup cannot be replaced by delivering unrelated food.
The per-operation provenance length audit matches physical inventory.

## Three-day result

| Sparse scene | Disabled | Enabled |
|---|---:|---:|
| Ground food at end | 83 | 31 |
| Food actually removed from ground | 13 | 65 |
| Final private stocks A/B/C | 11 / 1 / 0 | 23 / 29 / 11 |
| Consumed | 5 | 6 |
| Final carried | 0 | 0 |
| Maximum radius from home A/B/C | 18.00 / 3.55 / 5.55 | 37.45 / 37.08 / 33.71 |
| Selected route candidates A/B/C | 0 / 0 / 0 | 3366 / 844 / 581 |
| Direct route support admissions A/B/C | 0 / 0 / 0 | 4 / 5 / 3 |

Initial total100 includes ground96 and initial inventory4. End conservation:
disabled83+12+5=100; enabled31+63+6=100. Pickup action counts include attempts;
transition records are compressed and must not be counted as individual pickups.
Ground depletion is the actual acquisition total in this no-regeneration scene.
Route admission counts are supported legs, not independent episodes or deposit
counts. Eleven final route nodes have positive support across the three agents;
reverse proposals remain separately identifiable.

All agents completed Sleep on all three nights and ended within home contact in
these runs. Consecutive day-start physical states match preceding night ends.
The shared camp scene is unchanged: ground0, stocks10, consumed6, total16;
no route formation or route selection. Its tower is excluded from color routes.

Both fresh landmark candidates and remembered route candidates were enabled
together. This comparison does not isolate route learning from landmark-directed
exploration, prove efficiency improvement across seeds, or prove absence of
local circling. Radius is observer-only output and never enters agent selection.

## Remaining LW work

Full multi-landmark angular constraint composition, elevated skyline, tracking
through occlusion and unsuccessful route-leg completion evaluation are unported.
The home beacon and atomic turn-step remain provisional. General harvest Sleep
still reports INSUFFICIENT_EVIDENCE, despite actual pickup and route admission;
route support is an explicit execution path, not canonical T1 or Sleep adoption.
The next integration boundary is connecting actual living outcomes to the
existing Sleep learning materials, while preserving the current causal limits.

No full repository suite or long-duration performance benchmark was run for
this finite adapter. The 48.4s initial integration test duration includes four
scenarios and test overhead and is not a Python/Julia speed comparison.
