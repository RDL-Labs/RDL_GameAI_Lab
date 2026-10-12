# LW telemetry disabled comparison

Status: implementation tested; one-day cloud comparison pending.

Compare events/off sequentially on the same Ubuntu 24.04 runner, Python
3.12.15, hash seed 0, human_scale_v1, one day, one-second observations,
movement inertia enabled. Both use the same campaign options and seed.

`off` bypasses telemetry row construction, EventLog aggregation, JSONL writes,
observer callbacks, progress maps and the post-run receipt audit. It does not
remove agent observations, experience, learning, World receipts or internal
history: these may be behaviorally significant. Final summary, options and
supervisor status are retained solely for measurement. No per-operation audit
can be claimed for off. Simulation elapsed time and total supervisor time are
reported separately; the latter includes output and postprocessing.

The short full/events/off comparison preserves identical final state excluding
elapsed time, creates no log directory in off, and rejects an off-mode observer.
Event logging plus Sleep receipt boundary tests: 8 PASS.

Workflow: `.github/workflows/lw-log-off-comparison.yml`. It requires identical
final summaries excluding elapsed time, and reports percentage time reduction,
speedup and log size. One sequential pair estimates this workload only; order,
runner load and timing noise prevent a general performance conclusion.
