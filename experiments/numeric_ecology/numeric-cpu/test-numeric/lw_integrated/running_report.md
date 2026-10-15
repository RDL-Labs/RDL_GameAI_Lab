# Finite danger-running in the native LW loop

2026-10-13 / code `0aa41e4`.

`--running on` adds running to currently observed danger response. Default is off;
ordinary food/home exploration remains walking. This is the first body-operation
increment, not the completion of climb/drop or learned urgency.

## Contract

Coefficients follow Python layered_body: run distance1.5*(1-damage), reserve cost
0.5*effort*RS, burst cost3*effort, strain gain0.18*effort*SS. Effort includes load
and locally sampled ground resistance. Feasibility requires sufficient reserve,
burst, strain<=0.8 and positive integrity. Blocked execution has zero displacement.

Run candidates have their own full-length clearance and midpoint resistance sample,
not the shorter walk clearance reused as permission. Current relative danger and
feasible walk/run samples enter a bounded fixed separation-minus-effort ranking.
No run feasibility leaves walking/scanning available. Each action has one body
update. Successful run does not resolve food/home H, grant route support, or prove
safety; unseen-danger release still uses the existing local warning-basis review.

At most32 source-bound actual run records per agent retain load, resistance,
distance and expected/actual deltas. No new terrain or running model is learned.
The midpoint resistance approximation remains; it is not continuous integration.

## Evidence

[run38336518183](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38336518183):
Julia-only, native seed20261005, renewable food, flat ground, crossing hazard,
three days each with running off/on. Each executes155,520 operations.
42 checks pass: safety16, running15, integrated invariants8, actual correspondence3.
Local checks include load/burst/resistance limits, full-run blockage beyond walking
clearance, injury-scaled distance, and fallback to walking when burst is exhausted.

| Agent | Actual runs | Run distance | Matching-context delta mismatches |
|---|---|---|---|
| A | 9 | 13.5 | 0 |
| B | 11 | 16.5 | 0 |
| C | 4 | 6 | 0 |

All24 run attempts were performed. Total36 units are run displacement only, not
the whole-life distance or guaranteed successful escape. Ground patch interaction
is supported by the shared sampler but the living comparison used flat ground;
high resistance/load limits were tested locally.

| Condition | Added | Ground | Stock A/B/C | Carried | Consumed |
|---|---|---|---|---|---|
| off | 76 | 47 | 57/60/0 | 5 | 7 |
| on | 96 | 42 | 83/18/41 | 5 | 7 |

Initial food100; both ledgers balance. C had incomplete Sleep on nights1/3 in off;
B had incomplete Sleep on nights1/3 in on. Other nights completed. These outcomes
are retained, not forced into all-home/all-Sleep acceptance. Supply is endogenous
to previous harvest under the renewal rule; stock117 ->142 is not an equal-supply
efficiency result. This is one seed and finite fixed safety ranking, not learned
running or an isolated universal effect of faster movement.

Off result matches run38334456523 seed05 after removing the new null running and
ground diagnostics. Full repository suite and performance comparison were not run.
Initial fixture placed a run-only obstacle inside the walk clearance margin;
the revised fixture at1.4 with radius0.05 tests the intended separate horizons.

Next: climb and load disposal within this same loop, with separate physical
possibility and parent-goal outcomes. No new standalone living simulation needed.
