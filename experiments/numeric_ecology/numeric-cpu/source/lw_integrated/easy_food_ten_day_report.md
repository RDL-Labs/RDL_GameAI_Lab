# Ten-day easy-food life with repetition pressure

2026-10-14. Runtime base f761aa5. The previous easy-food scene is unchanged:
three actors, food13 units from camp (visibility12), no hazards, flat ground,
visible camp beacon. A million units exceeds the entire ten-day operation count.

Repetition pressure is enabled in BOTH conditions. Parent breadth is off/on.
Each run is10 continuous days (518,400 actor operations), not10 initializations.
Source spec retains the same learning/body/route options. Parent-H, method-H,
repetition coefficients and action rules were not tuned for this run.

Evidence: `outputs/easy-food-ten-day-1`, including frozen per-mode specs, full
results, summaries and per-day audits. The runner now accepts optional DAYS and
REPETITION_MODE, preserving3/off defaults. Maximum10 days and fresh output only.

Commands:

```sh
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/easy_food_experiment.jl SPEC OUTPUT 10 on
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/easy_food_audit.jl OUTPUT
```

Timing is off then on in one process, with compilation/cache and trajectory
differences. No speedup claim follows from raw call times.

## Results

Both completed518,400 operations. Runner9 assertions and daily audit118 assertions
passed: daily conservation, finite body values,17,280 operations per actor-day,
and previous-night to next-day state continuity.

|Metric|Parent breadth off|Parent breadth on|
|---|---:|---:|
|Harvested A/B/C|34/45/28|13/36/16|
|Harvested total|107|65|
|Final shared stock|83|49|
|Consumed|30|22|
|Final reserve A/B/C|97.24/94.69/96.32|0/94.78/15.45|
|Sleep completed|30/30|30/30|
|Call seconds|150.345|187.217|

Daily harvest off:11,15,15,12,9,9,9,9,9,9.
Daily harvest on:11,6,15,12,6,3,3,3,3,3.
All final inventories zero. Off conservation1,000,006=999,893+83+30;
on1,000,006=999,935+49+22.

Enabled gate:172,446 decisions, full-width172,320 (~99.927%). Only83 decisions
restricted. Offered1,855,183 / admitted1,854,908 (275 fewer, ~0.015%).
The rare early differences still change downstream trajectories substantially.
This is one paired World, not an estimate of population-level risk or benefit.

On: B ends near camp at(0.13,4.92); A(-653.50,-3348.62) and
C(3806.45,1121.41) end far away. Travel A/B/C34,596/4,832.5/31,689.5.
Thus A/C did not settle into repeated camp-food trips. Reserve0 is the simulator's
energy floor, not evidence of a modeled death event. Sleep completion does not
imply replenishment of food energy.

## Interpretation

Repetition pressure permits sustainable daily harvesting in the off condition.
Parent breadth gating did not produce the intended low-cost stable routine here;
the enabled condition deteriorated for A/C. Parent H remains high for most method
decisions. The existing goal accounting treats ongoing travel without completion
as unresolved, so nearby food alone is not sufficient to establish low H.

Keep the feature opt-in. Do not tune coefficients to hide this result. Next useful
diagnostics are the first off/on decision divergence and the distinction between
progress toward a parent goal and lack of progress. No claim is made that the
entire difference is CPU overhead or that broadening candidates guarantees return.
No new runtime fixes or full suite/cloud run were included in this experiment.
