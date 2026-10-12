# Compact A2 execution experiment

Status: implementation, measurement pending. Baseline: 9ccf86c.

Applies the behavioral fidelity policy. Both conditions use incremental aid,
the same two A2 fixtures (enabled/obstacle), three finite days, 90 daytime
ticks and 2,880 night rest updates per day. This is not a full LW campaign.

`recording=:detailed` remains the default and preserves its output contract.
`recording=:compact` records action counts and transitions of
(day, action, target, direction, food reference, result status), plus existing
night and final snapshots. It does not record every observation, candidate,
body value or pressure snapshot. Full daytime reconstruction is lost.
The recording is never fed back into decisions. No learning/cadence/H changes.

Both conditions retain social ingest copies, operation receipt history,
duplicate-execution audits and per-tick conservation checks. Compact mode
also checks request targets against current observations. These costs remain
inside execution timing. This isolates recording costs rather than removing
test overhead only from the faster condition.

After warmup, measure ten samples of fresh full scenario execution (including
World setup, recording and nights), cumulative allocation, and separately JSON
serialization and byte length. Compilation, file I/O and artifact transport
are excluded. Not RSS, not production speed, not a long-run capacity claim.
State/action agreement is diagnostic; resource and Sleep checks are acceptance.
Explicit terminal records must not alias earlier nights.
