# LW observation cadence: three-day comparison

Status: short comparison COMPLETE; three-day coarse run pending launch (2026-10-09).

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
