# Four small optimizations: local and cloud ten-day acceptance

Runtime candidate: `cfc75d055d69f5437f06bd510782d4147315b597`.
Baseline: `08a569dbcc640ae27bf4923006ab971664c5dcce`.
Cloud workflow/audit correction: `45b3fce` (no runtime change).

Both environments run the same frozen riparian seed 20261005, three agents,
ten continuous days, 518,400 operations per variant. `ten_day_spec.json` preserves
the previous integrated 30-day configuration, with only duration shortened.
Each environment runs old then new in a single Julia 1.13.1 process, one thread.
Comparisons require exact decoded JSON equality, including continuous values.

Changes: ground analysis sharing, one-pass method choice/lazy node creation,
immutable BodyDelta, horizontal skyline intersection reuse.

## Local result

Both simulations and all checks completed with exit 0. Independent Python audit
confirmed full result equality, ten daily resource balances, final balance,
finite bounded body values, 518,400 operations per variant, overnight state
continuity and final position/body/inventory/stock matching the last night.

| Metric | Old | New |
|---|---:|---:|
| Call seconds (compilation included) | 340.140916 | 237.789950 |
| Cumulative allocation bytes | 146,327,491,733 | 115,482,546,603 |
| GC seconds | 13.570400 | 11.190351 |

Observed call ratio 1.43x, time reduction 30.1%, allocation reduction 21.1%.
Whole harness wall time was 598.251 seconds including both variants and tests.
Peak RSS is cumulative within one process and cannot compare the variants.
Evidence: `outputs/lw-optimization/quick-ten-day/results/independent-audit.json`.

## Cloud result

Successful run [38480104507](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38480104507),
job 115580318444, artifact 11857980862. Both ten-day simulations completed and
all 3,655 assertions passed (3,646 local mechanism checks, one full equality,
eight integrated invariant checks).

| Metric | Old | New |
|---|---:|---:|
| Call seconds (compilation included) | 655.361107 | 423.005608 |
| Cumulative allocation bytes | 146,300,747,576 | 115,456,611,104 |
| GC seconds | 15.135566 | 12.606084 |

Observed call ratio 1.55x, time reduction 35.45%, allocation reduction 21.08%.
Independent audit of the downloaded artifact confirms the same ten-day gates
as local. **The entire decoded result also matches across Windows local and
Linux cloud exactly**, not merely their aggregate counters. Frozen spec SHA-256
is identical: `8d83fac65b9dbf5c59da9ad5e0a1c4b2ec4320a5148e00449d43e0c975b1b6ca`.
Evidence: `outputs/lw-optimization/quick-ten-day/cloud/results/independent-audit.json`
and `cloud/job.log`. Local and cloud each run 1,036,800 operations across old/new.

The first run 38479853549 failed before Julia setup because checkout treated the
short baseline SHA as a branch/tag. It was replaced with the full SHA; no
simulation result from that failed setup is counted.

## Interpretation limits

This is one fixed-order pair per environment, not a randomized repeated timing
study. Compilation is included and PC/runner variation remains possible. The
earlier ground-only ten-day baseline took 517.5s on the same PC, versus 340.1s
here: do not compare timings across those runs to isolate the additional changes.
Allocation is cumulative, not retained memory or a leak indicator. This tests one
seed and the explicit enabled configuration, not all LW combinations.

## Acceptance

The requested local and cloud ten-day experiment is complete. Retain these finite
optimizations: their outputs, body bounds, resource balances and overnight state
continuity passed both environments. No resolution, observation cadence, goal
rules or learning coefficients were changed. This is not a full Python suite or
all-seed acceptance. The experimental branch holds the runtime and workflow;
publication to main is separate from this experiment.
