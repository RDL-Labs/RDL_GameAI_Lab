# Finite local ground resistance in native LW

2026-10-13 / implementation `9d8d0e2`.

The native living loop now connects World resistance patches, five observed local
samples, load-dependent predicted body cost, ordinary candidate priority, actual
body cost and bounded operation records. Default flat mode preserves prior behavior.
Normal startup no longer executes testsets; explicit checks.jl/validation runners
own them. Runtime conservation assertions remain in the simulation.

## Contract

`--ground flat|shadow|patches`: flat=1.5 everywhere; shadow=patch physics and
observation without extra priority projection; patches=same physics with projection.
Shadow is not action-neutral, because actual cost and feasibility affect living.
Patch centers/radii/resistances: (0,5)/3/4 and (12,12)/6/3. Overlap takes maximum.
World parameters are not passed to agent candidate selection. Agents receive five
immediate resistance/effort samples. No global path planning or forced safe route.

Sample and execution use the midpoint of the half-unit damage-scaled step.
Priority penalty is 0.25 times excess reserve effort over baseline1.5, including
load multiplier (1+0.1*load). Feasibility gates remain mandatory. No candidate is
invented and no method is relabeled as rest. Existing survey remains its own method.
Safety priority is unchanged. Ground-independent harvest learning is unchanged.

Each agent retains32 latest actual movement records, bound to operation ID, with
load, resistance, status, expected and actual deltas. Mismatch counts are cumulative
for matching clearance/load. The pre-existing one-unit observation clearance and
half-unit execution clearance differ; nonmatching contexts are not false matches.
Records are diagnostics/experience material, not generalized Sleep-adopted terrain
models. No ground wear, run, climb, drop, or continuous physical path integration.

## Evidence

[run38335615154](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38335615154),
Julia-only, native seed20261004, three continuous days, renewable food, full finite
harvest learning and crossing hazard. Each condition executed155,520 operations.
48 assertions passed: safety16, ground/method14, invariants12, correspondence6.
All three conditions completed all nine agent-night Sleep cycles.

| Condition | Added food | Ground remaining | Stock A/B/C | Carried | Consumed | High-resistance walk operations |
|---|---|---|---|---|---|---|
| flat | 90 | 84 | 29/17/36 | 18 | 6 | n/a |
| shadow | 77 | 42 | 53/23/47 | 6 | 6 | 1775 |
| patches | 64 | 78 | 18/25/31 | 6 | 6 | 850 |

Initial food100 in all conditions; all ledgers balance. Matching-context predicted
vs actual delta mismatches were zero. Retention stayed at32 records per agent.
Actual walk-operation totals: shadow69,259; patches70,672. These counts include
walk attempts, not an unconditional claim of traversed distance.

Projection reduced aggregate high-resistance walk count but did not improve food
storage:123 ->74. C's high-resistance count increased425 ->631, while A/B fell.
No universal efficiency or avoidance claim follows. Resource additions also differ
because renewal restores depleted stock. The local test separately shows an
otherwise identical two-candidate choice changing from front to side when ground
effort is included. Full-run divergence includes later body and social interactions.

Flat result matches run38334456523 seed04 structurally after removing the new
`ground_effects=null` diagnostic. No whole-repository suite or performance benchmark
was run. Initial run38335541685 caught an output-key collision between food `ground`
and ground diagnostics; `9d8d0e2` separates `ground_effects`, then reran successfully.

## Next boundary

Finite run/climb/drop adapters can now use the same local World/body contract.
Ground-context generalization in Sleep remains separate, as does world path wear.
