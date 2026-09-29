# L15A — Measured campaign interruption

Status: DIAGNOSTICS IMPLEMENTED; ONE-DAY SMOKE PASS; LONG RUN INTERRUPTED.
Date: 2026-09-29. Baseline `b5aefa7` plus source-hashed observer instrumentation.
[Contract](../experiment-contracts/LUANTI_L15A_campaign_timing.md).

## Actual experiment

Run `l15campaign-cc83773e7a58`: six agents, steady natural_meadow, eight patches
of twelve units, 1x speed, thirty days maximum / six returned batches, current
harvest and model-field enabled. No behavior, clock, queue capacity, action
budget, acquisition schedule or GC policy was adjusted.

The run passed day 16. It stopped at `1457763230` us, day 23 + 49.763230 seconds,
with `per-agent pending capacity`, not `missed acquisition slot`. A reached nine
pending items against the existing limit of eight; B–F each reached eight.
B/E acquired twelve units each: 24 total, two returned batches. The run exited 1
and is not clean acceptance or a completed thirty-day experiment.

The previous day-16 interruptions were not reproduced. Instrumentation adds
wall-time overhead and changes allocation timing; this is not proof of a fix or
an exact matched behavioral comparison. The old interruptions remain unlocalized.

## Measured bottleneck in this run

| Runtime observe bucket | Largest loop call |
|---|---:|
| Day 8 | 442.680 ms |
| Day 13 | 899.107 ms |
| Day 15 | 984.091 ms |
| Day 18 | 1291.547 ms |
| Day 20 | 1627.921 ms |
| Day 23 | 2053.777 ms |

The final slow call belongs to F's observation captured at `1455755740` us.
The World stops 2.007490 simulation seconds after that capture. Other agents'
last received observe replies refer to the same capture; F's reply never entered
the received-response Evidence. The shared HTTP lock covers the whole loop call.
A–E have outstanding result acknowledgments while F's observation is being
processed. Continued 250 ms sampling can therefore exhaust the finite queue
while one slow call holds all agents' request processing.

This localizes an actual >2-second interval inside Runtime observe. It does not
identify its internal source: Python GC, allocation/deepcopy, scheduling and
particular model/decision work were not separately timed. Capture timestamps
are not HTTP start/end wall timestamps. No exact network-delay decomposition
or causal claim about GC is made.

At the failing World callback, `dt=31884` us and measured work is `4153` us.
Across the run the maximum World `dt` is `264292` us and callback work `263999`
us; the largest World work intervals occur in sampling. No missed acquisition
slot was reported. A step slightly longer than 250 ms does not necessarily skip
an entire slot; the actual slot transition determines the assertion.

## Memory and export are separate observations

- Last pre-export Lua heap sample: `5117660.734375` KiB (~4.88 GiB).
- Full World JSON: 851,909,755 bytes.
- World Evidence export: `353577627` us (~353.58 seconds), after the run stopped.
- Post-export Lua heap sample: `30697690.24609375` KiB (~29.28 GiB).
- One manual process-working-set sample during export: 53,466,898,432 bytes
  (~49.8 GiB). This is a single host observation, not a measured peak or a
  pre-failure memory value.

Thus expensive final serialization is real, but cannot explain this run's earlier
pending-capacity failure. `collectgarbage("count")` is Lua heap, not process RSS.
The daily diagnostic flush and the large final Evidence export are separately
timed; neither value is an agent observation.

## Verification and scope of replay

- One-day actual Luanti smoke `l15campaign-aa19f850e3d3`: PASS, 256 observations
  per agent, no expired/stale/stopped actions, three pickups, no return batch.
  Export measured separately at 6.743670 seconds.
- Main run: 69,887 received HTTP responses replay exactly.
- Final actual Runtime is **not** exactly the received-prefix replay. It includes
  F's one additional accepted observation and A–E's five accepted action results
  whose replies are absent from World receive Evidence. Calls may settle during
  final export. Both actual Runtime and the received-response prefix are retained;
  the analyzer reports the discrepancy and does not overwrite either.
- Actual Runtime has 5,824 observations per agent. Received-prefix replay has
  5,824 for A–E and 5,823 for F. World capture counts are 5,832 for A and 5,831
  for B–F; captured but unsent observations are not called Runtime-accepted.
- Diagnostic rings are bounded at 128 entries each. Day buckets are at most 32.
  All recorded implementation source hashes match the measured checkout.
- 34 related Python tests PASS (3 diagnostics, 3 population, 4 campaign, 7 current
  harvest, 11 model field, 6 day cycle). Tests ran after the main World ended.
  Full repository suite was not rerun locally.

An initial smoke launch failed before World execution because the installer did
not yet copy the new module. The installer was corrected before the successful
smoke and the single main attempt; no failed long run was replaced.

## Artifacts and next boundary

- `tests/fixtures/luanti_l15a_campaign_timing_world.json.xz`: actual main run,
  live final Runtime and bounded diagnostics.
- `tests/fixtures/luanti_l15a_campaign_timing_audit.json`: replay, source hashes,
  per-agent delivery tail, and unreceived acknowledgments.
- `tests/fixtures/luanti_l15a_campaign_timing_smoke.json.xz`: actual smoke run.

```powershell
python -m integrations.luanti.tests.run_return_campaign --agents 6 --periods 30 --speed 1 --model-field enabled --harvest-state --diagnostics --output integrations/luanti/output/measured-campaign.json.xz
python -m integrations.luanti.tests.analyze_campaign_timing tests/fixtures/luanti_l15a_campaign_timing_world.json.xz --replay --output integrations/luanti/output/measured-audit.json
```

Next: isolate the long Runtime observe interval (including passive GC timing and
history-copy work) and reduce Evidence export overhead without changing agent
semantics. No queue enlargement, timing relaxation, forced GC, lost-observation
substitution or behavioral workaround is implemented in this change.
