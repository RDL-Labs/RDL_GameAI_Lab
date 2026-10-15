# Native safety clearance completion

Code: `7787569`; Ubuntu / Julia 1.13.1.
[Run 38352349275](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38352349275)
passed 61 assertions: safety 16, shared Sleep observation 4, method H 11,
limited clearance 19, living invariants 8, bounded methods 3.

`moving_hazard_safety.review` supplies two additional release paths: two
consecutive complete far observations, or signed accepted 90-degree scans
covering a full rotation while no threat is observed. Alternating scans,
partial coverage and missing accepted results do not establish a full survey.
The separate basis-H provisional release remains. No action budget is restored.
These are limited clearance judgments, not proof of globally absent danger.

Same native three-day mixed-hazard/food-body/Sleep loop, seed 20261005:

| Mode | Added food | Ground | Stock A/B/C | Consumed | Sleep A/B/C |
|---|---:|---:|---|---:|---|
| Legacy | 32 | 86 | 13/10/7 | 11 | 0/1/2 |
| Continuous with clearance | 24 | 82 | 11/10/9 | 12 | 2/1/0 |

Initial food is 100. Legacy carries 5; continuous carries 0. Both conserve
food. Limited releases occurred A=18, B=6, C=2; total safety selections were
3009/4354/5707. No general efficiency or Sleep improvement is claimed.

Measured call times were 43.18s (legacy first call, compilation included) and
29.14s (continuous subsequent call). Different paths and compilation exposure
make these unsuitable for a speed ratio. Allocations were 15.23/14.57GB
cumulative; process peak RSS was 911.55/919.20MB, not final retained memory.

This run also validates current dynamic hazard context for Sleep. It predates
the separate return-route attribution correction and is not final long-run
acceptance. Full native sensor coverage and remaining LW migration are open.
