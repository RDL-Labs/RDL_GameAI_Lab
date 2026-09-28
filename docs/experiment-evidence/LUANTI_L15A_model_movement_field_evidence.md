# L15A — M_B movement-field connection

Status: FINITE CONNECTION IMPLEMENTED; WORLD POSITIVE MODEL EFFECT NOT YET OBSERVED.

Baseline: `49c4806`. Contract:
[adopted harvest approach field](../experiment-contracts/LUANTI_L15A_model_movement_field_contract.md).

## Synthetic admission and control

11 dedicated tests PASS, included in 142 related regression tests PASS.
The model is formed by the existing actual Runtime admission functions using synthetic
observations and reported outcomes: three formation operations, two unused validations,
T1 material selection/reconstruction and cutover. It is not a hand-written adopted-model
stub. These are Python tests, not World-generated training data.

With the same observation, same frozen adopted model and same learning state, the fixed
approach-appraisal projection changes a finite test geometry's final command:

| Field mode | Final command |
|---|---|
| disabled | move 1 |
| enabled | turn 90 |

The test geometry intentionally lies near the existing heading-persistence boundary;
it establishes causal wiring, not general movement improvement. The rule/gain is a fixed
local use policy; its induction was not tested. A far material's harvest forecast remains
`unknown` even while approach-to-test appraisal contributes.

Other checks cover bounded source costs, independent snapshots, invalidation, missing
observations, profile mismatch, excluded ground, foreign model, future provenance,
concurrent repeated observe, preserved pickup/return/night gates, and unchanged learning
state between enabled/disabled projection. Existing day-cycle and steering/rest/
reactivation/reassessment/reversal regressions are included. Full repository suite not run.

## Real World comparison

Predeclared natural_meadow, A/B/C steady, three continuous 64-second days per mode,
1× speed, disabled then enabled; no mid-run parameter change. The existing 30-day/three
batch capability remains available but this check is a bounded integration smoke run.
No new Sleep, memory admission, sensor cadence or movement budget was added.

Artifacts:
- `tests/fixtures/luanti_l15a_model_field_disabled.json.xz`
- `tests/fixtures/luanti_l15a_model_field_enabled.json.xz`

The runner saves raw World and Runtime state before audit, then performs full HTTP replay,
body/sensor/stock/return checks, and strict transport acceptance. The post-run analyzer
records model availability, field applications, terrain-minimum changes and source hashes.
Both runs completed with strict transport acceptance. No synthetic choice difference
is counted as a World choice difference.

| Mode | Run | Observations | Pickups / returns | Adopted models | Applied field | expired / stale |
|---|---|---:|---|---:|---:|---|
| disabled | l15campaign-b8bcf9eb37c9 | 2,304 | 0 / 0 | 0 | 0 | 0 / 0 |
| enabled | l15campaign-51efe5364d90 | 2,304 | 0 / 0 | 0 | 0 | 0 / 0 |

Each agent produced 768 observations over three days. In each run A had 26 and B had
36 frontal-food terrain decisions, all with `no_adopted_model`; C had none. Current
priority/day-phase decisions stayed on their existing path. Source hashes match the
tested checkout. The two runs demonstrate integration and absence handling, **not real
World model-attributable movement or harvesting improvement**. The next positive test
needs actual admitted experience; no model or success was injected into these Worlds.

## Subsequent 30-day experiment

See [30-day comparison](LUANTI_L15A_model_field_30d_evidence.md) for the longer
World experiment, including the interrupted attempt and timing acceptance limits.
The three-day results above remain the original smoke comparison.

## Reproduction

```powershell
python -m integrations.luanti.tests.run_return_campaign --periods 3 --speed 1 --model-field disabled --output integrations/luanti/output/field-disabled.json.xz
python -m integrations.luanti.tests.run_return_campaign --periods 3 --speed 1 --model-field enabled --output integrations/luanti/output/field-enabled.json.xz
python -m integrations.luanti.tests.analyze_model_field tests/fixtures/luanti_l15a_model_field_disabled.json.xz tests/fixtures/luanti_l15a_model_field_enabled.json.xz
```

Default `--model-field off` is the original campaign. Source-code hashes in each artifact
identify the tested implementation. Future revisions can legitimately differ from them.
