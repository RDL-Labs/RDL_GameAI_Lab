# Julia LW inertia living comparison

Source: 213c9e5. [Actions](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38358869722): 51 assertions PASS.

A confirmed actual move may continue the same method in the current forward direction. Current food, hazard/unknown coverage, unavailable body/surface, purpose change, stale receipt or retired method interrupt it. Repeated subjective views accumulate separate local H; threshold returns control to normal selection. No physical momentum or permanent goal lock is claimed.

Seed 20261005, three actors, three continuous days, renewable food, mixed hazards. Each run executes 155,520 operations.

| Mode | Added food | Ground | Stock A/B/C | Carried | Consumed | Completed Sleeps A/B/C |
|---|---:|---:|---|---:|---:|---|
| off | 16 | 87 | 11/0/6 | 0 | 12 | 0/1/1 |
| on | 20 | 81 | 6/6/15 | 0 | 12 | 2/3/1 |

Continuation selected 3,309 times (A1,527/B801/C981). The view signature is a finite Julia-native approximation (local ground availability, landmarks, food and hazards), not full Python sensory parity.

The configurations differ between these two experiments: inertia also enables the angular relation field. Do not compare their off conditions as identical. Sleep pending is retained. Food supply depends on prior harvesting, so stock differences do not establish efficiency gains. Initial calls include compilation; no language speedup claim. Full Julia LW migration remains incomplete.
