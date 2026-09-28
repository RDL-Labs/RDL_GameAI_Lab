# L15A — Current harvest state: actual World run

Status: ACTUAL RUN INTERRUPTED; CURRENT-STATE PREFIX VERIFIED. Not full campaign acceptance.

Date: 2026-09-29. Baseline: `3415651`. Run: `l15campaign-c8e93feb4b73`.
[Contract](../experiment-contracts/LUANTI_L15A_current_harvest_state.md).

## Conditions and outcome

A/B/C, natural_meadow, steady profiles, 1× speed, model-field enabled and
`--harvest-state`. Maximum thirty 64-second days or three aggregate returned
batches, with unchanged sensing, movement, learning and return budgets.
No runtime implementation or parameters were changed during the run; all stored
source hashes match. One attempt was executed and retained, without replacing it
with a successful retry.

The World stopped at `994588833` simulated microseconds: fifteen full days and
part of day sixteen. The fixture raised `missed acquisition slot` at its existing
consecutive-slot assertion. Maximum step was `7719774` microseconds (about 7.72 s),
longer than the 250 ms acquisition interval. Why that long step occurred is not
established. We do not infer a host sleep, CPU cause or Runtime exception from it.
Runner exited 1 and preserved both actual World and live Runtime before rejecting
acceptance. No observations were fabricated to fill the missed interval.

| Agent | Pickups | Pickup day(s) | Returned batches | Historical success records |
|---|---:|---|---:|---:|
| A | 0 | — | 0 | 0 |
| B | 12 | 9 | 1 | 12 |
| C | 24 | 6, 15 | 1 | 24 |

Total: 36 units, two returned batches; third-batch goal not reached. C's second
12-unit acquisition was not counted as another return. Compared with the prior
run, extra acquisition is not attributed to current-state recording: that feature
adds explicit state and does not change command selection, and this is not a
matched-timing causal experiment.

## Current absence and historical success

Each agent recorded 3,948 observations, total 11,844. Every `current_harvest` state
was recomputed from its own Food observation and only its own records whose later
capture time was already reached. All matched. No `none_observed` decision issued
a pickup command.

| Agent | None observed | Visible out of reach | Reachable observed |
|---|---:|---:|---:|
| A | 2,457 | 1,482 | 9 |
| B | 2,451 | 1,481 | 16 |
| C | 2,374 | 1,374 | 200 |

These are observations, not distinct places or acquisition successes. This actual
run contains no partial Food acquisitions; `unknown` remains covered by the prior
synthetic tests, not by this run.

After B's twelfth pickup, observation 2105 said `none_observed` with twelve successful
records retained; the existing landmark controller selected `turn -45`. After C's
first twelve pickups, observation 1390 said the same, but the existing exhausted
landmark budget selected `wait`. Absence therefore does not manufacture new action
budget or guarantee immediate exploration. Later C's success count reached 24.

B/C's combined harvest-and-persistence models remained invalidated. Their historical
successes survived; no narrower M_B was silently adopted or resurrected. Model-field
applications were zero. Periodicity/regrowth and learned movement improvement were
not established.

## Validation and artifacts

All 23,691 saved HTTP responses replayed exactly, and the complete resulting Runtime
snapshot matched the saved live snapshot. Returned batches were independently
recounted from World actions and pickups and matched the two recorded batches.
No expired, stale or stopped action results occur in the recorded prefix, but that
does not override the acquisition-slot failure or establish complete acceptance.
This is a verified interrupted prefix, not a 30-day PASS.

- `tests/fixtures/luanti_l15a_current_harvest_world.json.xz`: actual World and Runtime.
- `tests/fixtures/luanti_l15a_current_harvest_world_audit.json`: counts, provenance,
  hash verification, exact failure and post-run audit result.
- `integrations/luanti/tests/analyze_current_harvest_world.py`: reproducible audit.

No new full repository unit run was performed; runtime code was unchanged from the
preceding 51-test validation. The current run added actual World execution, exact
response/state replay and per-observation provenance checks.

```powershell
python -m integrations.luanti.tests.run_return_campaign --periods 30 --speed 1 --model-field enabled --harvest-state --output integrations/luanti/output/current-harvest-world.json.xz
python -m integrations.luanti.tests.analyze_current_harvest_world tests/fixtures/luanti_l15a_current_harvest_world.json.xz --replay --output integrations/luanti/output/current-harvest-audit.json
```
