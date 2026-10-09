# LW observation cadence: three-day comparison

Status: short comparisons COMPLETE; three-day 1-second run FAILED with native access violation (2026-10-09).

Observation cadence is configurable as 250 ms (default) or 1 s. World updates remain 250 ms; body completion, metabolism, terrain recovery and hazards still advance at that cadence. No budget reset or time-profile change is introduced. The existing strict post-completion observation binding is preserved: an observation coincident with completion does not immediately authorize another action. Therefore this is a changed observation/decision experiment, not behavior-preserving acceleration.

## Controlled short comparison

Same current code, seed 20261005, three agents, human_scale_v1, inherited LW integration options, 180 World seconds. Runs executed sequentially.

| Observation interval | Captures | Completed actions | Wall time including audit | JSONL bytes |
|---|---:|---:|---:|---:|
| 250 ms | 2160 | 432 | 13.1633 s | 32904562 |
| 1 s | 540 | 270 | 3.9981 s | 13823278 |

Wall time fell approximately 70%; log bytes fell approximately 58%. Both runs passed food conservation and no duplicate/overlapping effects. These are single short measurements, not a guaranteed long-run speedup. Fewer decisions change trajectories and social outcomes.

Outputs: `outputs/cadence_250ms_180s_20261009` and `outputs/cadence_1s_180s_20261009`.

## Three-day run

Command: `python -X faulthandler -m integrations.lightweight.long_ground_campaign --days 3 --observation-us 1000000 --output outputs/ground_3d_obs1s_20261009`

Uses bundled Python 3.12, fixed hash seed through the supervisor, 51,840 World seconds, no early return-count stop. Status, progress, daily ground maps, final summary and audit are written under that output directory. Completion and actual three-day sizes must be checked there before treating the run as evidence. No matched three-day 250-ms baseline has been rerun.

Validation: 24 focused tests passed (observation cadence, ground observer, movement commitment, continuous selection and LW time). Full suite not rerun.

The preceding 30-day attempt `outputs/ground_30d_20261009` failed after 36.384 s with native exit `0xc0000005`. Its logs remain preserved; it did not complete 30 days. The cadence change is not a demonstrated fix for that intermittent native crash.

## Five-second observation follow-up

Added optional 5-second cadence with the same 250-ms World updates. The same 180-second scenario completed in 1.1028 seconds including audit, with 108 captures, 108 completed actions and 4,289,098 JSONL bytes. Conservation and duplicate/overlap audits passed. Relative to 250 ms, this is approximately 92% less wall time and 87% fewer bytes; relative to 1 s, approximately 72% and 69% less. Single short runs only.

Crucially, a one-second body operation is followed by waiting for the next observation: fewer actions, not merely cheaper logging. This changes available daily movement and reaction latency. No 30-day performance or behavioral equivalence is established. The 24 focused tests passed with 5-second cadence included.

The three-day 1-second run failed after 17.4313 seconds with exit 0xc0000005. Logs remain in outputs/ground_3d_obs1s_20261009. It did not complete three days. The five-second short-run output is outputs/cadence_5s_180s_20261009.
