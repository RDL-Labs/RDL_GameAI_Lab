# L15A — 30-day model-field comparison

Status: BOTH 30-DAY WORLDS COMPLETED; STRICT TIMING ACCEPTANCE FAILED.
REAL WORLD MODEL ADMISSION OBSERVED; MODEL-FIELD APPLICATION NOT OBSERVED.

Baseline: `ff6ef560`. [Connection contract](../experiment-contracts/LUANTI_L15A_model_movement_field_contract.md),
[prior three-day evidence](LUANTI_L15A_model_movement_field_evidence.md).

## Fixed conditions

A/B/C, `natural_meadow`, all `steady`, 1× simulation speed, one continuous World
per attempt, at most thirty 64-second days or three aggregate returned batches.
A batch is one agent/night with previously uncounted pickup operations. World stock,
agent memory and adopted models persist across days; no extra goal-budget resets.
The mode is disabled or enabled. No model, harvest outcome or resource position was
injected into the agents. Runs have distinct run IDs and real scheduling; they are
not an identical packet-stream causal comparison.

The launcher gives long-campaign JSON export 300 seconds of wall-time margin after
the simulated task, rather than the previous 35 seconds. It does not extend agent
budgets. Agent behavior, cadence, gain and model-admission rules remain unchanged.
This launcher change was present for all three attempts; artifact source hashes
identify the tested checkout, in addition to the baseline commit.

## All attempts, including failures

- Initial disabled: `l15campaign-dec956f3829a`, local HTTP connection failure during
  day 7 (`finished_us=426350662`; six full days). Curl reported `Could not connect to
  server` for `/v1/exploration/result`. The underlying cause is not established.
  Its raw World is preserved in `luanti_l15a_model_field_30d_disabled.json.xz`.
  The initial runner asserted World success before taking a Runtime snapshot, so
  that live Runtime state is unavailable (`runtime=null`). It is not inferred as
  zero models or zero effects. The 10,236 saved successful responses replay exactly;
  a separately labelled reconstructed prefix contains C's 12 experience records,
  an adopted model and its later invalidation. This prefix is not the lost live
  snapshot and does not establish completion of the failed final request.
- Enabled: `l15campaign-c892690b5f91`, thirty days, 23,040 observations (7,680 each).
  World completed and full replay matched, but strict timing acceptance failed:
  47 expired commands, two stale commands, zero stopped commands. Runner exit 1.
  It acquired 24 units and returned two batches: C on day 6 and B on day 9,
  twelve units each. Three-batch target not reached. A acquired none.
- One unchanged disabled retry was declared after the connection failure and
  started after enabled completed: `l15campaign-15b075564e07`. It completed thirty
  days and full replay matched. It also acquired 24 units and returned two batches
  (C day 6, B day 9; twelve each). Strict timing acceptance failed with 27 expired,
  zero stale and zero stopped commands; runner exit 1. The original failed attempt
  remains separately preserved.

The runner now saves partial World and live Runtime before rejecting a World
failure. This collection-only repair affects the retry; it does not change the
agent. Two mocked failure-preservation/analyzer tests pass. They are not World
acceptance tests. The full repository suite was not rerun for this experiment.

## Completed comparison

| Mode | Days | Pickups | Returned batches | Adopted / later invalidated models | Applied field | Expired / stale |
|---|---:|---:|---:|---:|---:|---|
| disabled retry | 30 | 24 | 2 / 3 | 2 / 2 | 0 | 27 / 0 |
| enabled | 30 | 24 | 2 / 3 | 2 / 2 | 0 | 47 / 2 |

Both completed runs contain 23,040 observations and 24 experience records, twelve
each for B/C. A formed no model. All recorded source hashes match this experiment
checkout. Full replay, sensory/body/stock checks and independent return counting
passed in diagnostic mode; this does not override failed strict timing acceptance.
Mode-only behavioral improvement is not established: real timing and trajectories
vary, and no enabled field contribution occurred. Equal harvest totals do not
assert equal full action histories.

## Enabled model lifecycle

Both B and C formed and adopted the existing harvest relation from three formation
operations and two unused validation operations at one resource site per agent.
This is five distinct operations, not evidence from five independent sites.

The adopted relation predicts both `acquired=1` and `affordance_persists=1`.
At the final (twelfth) pickup, the observed comparison was:

```text
prediction: acquired=1, affordance_persists=1
later:      acquired=1, affordance_persists=0
difference: acquired=0, affordance_persists=-1
```

Thus acquisition succeeded but subsequent nearby affordance disappeared. The
existing invalidation latch disabled use of that whole adopted relation. Model
provenance remains saved; `active_model != null` does not mean it is still eligible.
No re-admission or narrower replacement relation is implemented here.

Between adoption and the first mismatch, B and C each had seven decisions, all
`pickup` under `existing_priority`. Neither had an eligible locomotion decision
while the model was valid. Enabled field applications and terrain-minimum changes
were both zero. This does
not demonstrate learned movement improvement. The next question exposed by this
run is how to separate evidence for acquisition from evidence for persistence,
and how a failed prediction should be inspected/revised. This experiment does not
silently weaken validation or bypass invalidation to obtain a positive effect.

## Reproduction

```powershell
python -m integrations.luanti.tests.run_return_campaign --periods 30 --speed 1 --model-field disabled --output integrations/luanti/output/30d-disabled.json.xz
python -m integrations.luanti.tests.run_return_campaign --periods 30 --speed 1 --model-field enabled --output integrations/luanti/output/30d-enabled.json.xz
```

Stored artifacts are under `tests/fixtures/luanti_l15a_model_field_30d_*.json.xz`.
Use `analyze_model_field` for post-run counts. A timing-dirty completed run can be
replayed with `check_return_campaign --diagnostic`; strict mode must reject it.
The aborted artifact is an incomplete record and cannot pass full-campaign replay.

The initial failed attempt is excluded from complete-run totals, not hidden.
The aggregate saved World observation count is 51,198: 5,118 interrupted plus
23,040 enabled plus 23,040 disabled retry. No extra runs were selected for success.
