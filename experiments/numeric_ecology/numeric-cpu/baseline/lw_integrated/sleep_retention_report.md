# Daytime outcome retention for Julia Sleep

Code `35cd620`; [run38346179956](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38346179956)
passed38 checks: safety16, retention10, integration8, live retention4.

## Contract and Python relationship

Python experience_bundle.py and bundle_sleep.py keep bounded selected sources
and preserve unused material across nights, but rely on hunger/conjunction and
usage/dormancy infrastructure not yet present in this Julia path. This increment
is a finite retention adaptation, not a claim to port those full subsystems.

`--sleep-retention strata` maintains the latest accepted record per action/outcome,
at most32 strata, regardless of success, usefulness or goal relevance. Replacing
a stratum moves it to most-recent position. New strata at capacity evict the oldest
and increment an explicit counter. Rest updates one slot rather than erasing all
daytime variety. Source id/context/time remain intact; records are not synthesized.
No age-expiry is introduced; rarely repeated strata may persist across days.
Within-stratum contexts/directions are not all preserved; this is a deliberate
finite lossy selection, not complete memory or an unbiased sample of all actions.

The Sleep selection remains at most six latest action/outcome strata. Formation
freezes copies before rest; interruption/refreeze behavior is unchanged. The
existing192-source action-model store deduplicates reused sources across nights.
Coefficients, model application, body, resource and purpose rules are unchanged.
Default `recent` preserves the old64-observation window. Capacity eviction did not
occur in the measured World (7/8/7 retained strata for B/A/C).

## Same-seed three-day comparison

Seed20261005, renewable food, general-sleep apply, other optional features off.
Each run155520 operations; all nine Sleep cycles completed.

| Metric | Recent | Strata |
|---|---:|---:|
| Model sources A/B/C | 3/5/3 | 17/13/14 |
| Application decisions A/B/C | 0/5054/0 | 10500/10050/10241 |
| Local selection changes A/B/C | 0/0/0 | 96/0/65 |
| Reviews with pairs | 2/9 | 9/9 |
| Private stocks A/B/C | 65/6/53 | 89/6/41 |
| Added food |107|95|
| Ground food |72|48|

Strata retains daytime walk/scan/pickup/deposit/eat/retrieve records. No blocked
walk was selected in these saved live reviews; B also has an unavailable refusal.
Preservation of both successful and blocked walk through long rest is tested
locally, not demonstrated as the live cause. New model use changes161 choices
when compared against no Sleep contribution at the same actual state. These are
not161 independent full-trajectory counterfactual experiments.

Recent ledger100+107=72 ground+124 stored+5 carried+6 consumed.
Strata ledger100+95=48 ground+136 stored+5 carried+6 consumed.
Both recomputed from downloaded summaries. Different extraction changes renewal;
stock increase is not efficiency under equal resource supply. C's stock decreases.
This establishes a live retention -> Sleep model -> selection difference, not
beneficial behavior, general learning, or canonical adoption.

## Python CI failure

Run38344390194 on3d5fba6 reported1416 tests, one import error,51 skips.
test_julia_moving_terminal imported a historical Git blob before its SCALED skip
condition; the shallow CI checkout lacked commit52a94225484f7e1771c4b4c3703c3eb9eef39730.
The test now imports that fixture only when SCALED. Local legacy run skips both
checks cleanly; human_scale_v1 executes both and passes. Dedicated historical
comparisons still require their frozen Git object; no fallback to current code
was introduced. Normal Python CI run38346180589 is still in progress at report
preparation, so full-suite success is not claimed.
