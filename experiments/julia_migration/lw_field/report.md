# B1d learned approach appraisal in continuous living

Implementation4dd6143, baseline5be5fbe.
[Cloud run38257579564](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38257579564)
passed14 native boundary assertions and10 living assertions (24 total).
Ubuntu24.04, Julia1.13.1. Same two scenes and three continuous days per mode,
three agents. [Contract](contract.md) documents the finite adaptation.

## Sparse-scene result

| Measure | Field disabled | Field enabled |
|---|---:|---:|
| Actual ground acquisitions | 65 | 84 |
| Final ground | 31 | 12 |
| Final private stock A/B/C | 23 / 29 / 11 | 23 / 20 / 39 |
| Final carried | 0 | 0 |
| Consumed | 6 | 6 |
| Applied decisions A/B/C | 0 | 3658 / 56 / 263 |
| Same-state counterfactual selection changes A/B/C | 0 | 99 / 1 / 5 |

Initial100 = ground96 + carried4. Enabled12+82+6=100; disabled31+63+6=100.
All three agents completed Sleep on every night and ended within home contact.
Day-start state equals preceding night end; one action per simulated second
and per-operation resource conservation remain checked.

There are3977 applied decisions and106 different selections relative to a
temporary same-state no-field selector. These are not106 independent trials or
the number of all differences between the diverging whole runs. Model/H/live
authority are not mutated by the diagnostic selector, nor does it execute.
At most8 examples per agent retain source/model/contribution details.

A's first change occurs at17,352s: no-field step_-90 versus field step_90.
Its model was formed on the first night. B's first change at34,633s follows
second-night formation; C's at17,711s follows first-night formation.
Downloaded examples were checked for post-formation timestamps and[0,.5]
contribution bounds. Final resource balances were independently recomputed.

Shared camp has no adopted local model and is unchanged: stock10, consumed6,
ground0, no field applications. The absence case does not manufacture a model.

## Interpretation and limits

Actual experience -> completed Sleep -> local model -> current visible-food
appraisal -> existing movement selection now runs in one Julia living loop.
The source model still predicts only near observed affordance. Far matching
food licenses approach-to-test, not a known successful harvest. This is a fixed
use rule, not learned reward, coefficient or Core E/H.

Python terrain source normalization is not ported: Julia uses a declared bounded
angular alignment contribution to current candidates. Return, rest, eating and
pickup priority gates remain unchanged. No candidates are added, no null-cost
direction is revived. The source records/model and method/goal H are unchanged
by projection; ordinary subsequent outcome updates still apply normally.

The native fixture demonstrates an actual selected-method change and tests
no-model, incomplete, future, foreign-agent, absent-target, blocked-row, scan,
input independence and far-prediction-unknown boundaries.

This one sparse seed gives more group stock, but B individually stores less.
No general efficiency/survival improvement follows. Subsequent interactions
between agents and depleted resources contribute to whole-run differences.
Repeated field application can still accompany local circling; application count
alone is not progress. Canonical T1, general Sleep and model invalidation after
later counterexamples remain unported. No full-suite or speed benchmark was run.

Next useful integration is evaluating later outcomes against the learned local
prediction, retaining discrepancies without equating absent observations with
failed harvesting. This should precede claiming stable adaptive learned behavior.
