# L15A — Current harvest availability

Status: FINITE OPT-IN IMPLEMENTED. Periodicity/regrowth and model reconstruction are out of scope.

## Contract

`ReturnCampaign(..., harvest_state=True)` records `current_harvest` in each accepted
observation's decision. The runner exposes `--harvest-state`; old replay defaults
remain unchanged. This state makes the existing controller's Food absence explicit;
it does not introduce an extra movement command or reset an exploration budget.

| State | Meaning |
|---|---|
| `reachable_observed` | Matching taught appearance observed within 1.25 pickup reach |
| `visible_out_of_reach` | Matching material visible, but none within pickup reach |
| `none_observed` | Complete Food acquisition has no matching material |
| `unknown` | Food acquisition is partial; absence cannot be concluded |

The judgment is scoped to that observation's run, agent, capture time and pose.
It is not a map of empty resource sites, permanent depletion, proof about the whole
World, or a forecast of replenishment. Far Food is not absence. Incomplete ground
or distant sensing can independently block movement even if Food acquisition is
complete. A later observation replaces current availability; no persistent location
identity is fabricated from appearance or pose strings.

Historical successes are counted from the individual's existing accepted acquisition
records and reference the last successful operation. Their original records remain
available in `learning.records`. They are episodic facts, not a new adopted relation.
The last successful pickup followed by an empty observation is still a success.
Replay of the same observation returns its saved decision without another update.

The existing controller already clears the Food approach when no current matching
material is visible, then follows the bounded landmark/survey path. Return, night,
body correspondence and exhausted budgets retain their authority. This feature does
not promise renewed movement when a higher-priority gate says wait.

## M_B boundary

The old adopted relation combines `acquired` and `affordance_persists`. Its recorded
counterexample and invalidation are preserved. We do not restore its authority by
renaming absence, deleting evidence or silently dropping a predicted dimension.
Successful episodes survive, but moving with a separately adopted acquisition-only
relation still needs an explicit inspection/reconstruction contract. No periodicity,
new Sleep path or resource-regrowth rule is added.

## Validation

Seven dedicated tests cover complete absence versus partial uncertainty, far versus
reachable Food, successful final pickup and preserved counterexample, observation
replacement, replay isolation, cross-agent separation and independent output data.
Including model-field, failure-evidence, multi-resource, return and day-cycle
regressions, 51 actual tests passed. An initial invocation named a nonexistent
`test_landmark_return_campaign` module; the corrected `test_return_campaign` and
day-cycle invocation passed all ten tests. Full repository suite not run.

`tests/fixtures/luanti_l15a_current_harvest_replay.json` is produced by replaying the
saved 30-day enabled World from the previous experiment. Every saved HTTP response
must match; each prior decision, after removing only the new state field, must match;
learning and adopted models must match exactly. This is offline execution over real
World input, not a new Luanti/HTTP run, and does not remove the original timing failures.

```powershell
python -m integrations.luanti.tests.replay_current_harvest tests/fixtures/luanti_l15a_model_field_30d_enabled.json.xz --output integrations/luanti/output/current-harvest-replay.json
python -m integrations.luanti.tests.run_return_campaign --periods 30 --speed 1 --model-field enabled --harvest-state --output integrations/luanti/output/current-harvest-world.json.xz
```

The second command is a future live-run entry, not a claim it was executed here.

## Actual-record replay result

46,086 saved HTTP responses and 23,040 decisions matched the prior run exactly
apart from the added current-state field. Learning records and adopted model
snapshots were unchanged. B and C each retained twelve successful acquisitions
while their first post-harvest absence was recorded at observations 2105 and 1390.
The combined persistence model remained invalidated, as required.

| Agent | None observed | Visible, out of reach | Reachable observed | Historical successes |
|---|---:|---:|---:|---:|
| A | 3,379 | 4,279 | 22 | 0 |
| B | 5,966 | 1,698 | 16 | 12 |
| C | 6,597 | 1,071 | 12 | 12 |

These are observation counts, not unique resource locations or independent negative
experiences. This real-record dataset contains no partial Food acquisitions; the
`unknown` boundary is tested with synthetic partial input. Reachable observations
are not successful actions (priority, body and expiry checks remain separate).
