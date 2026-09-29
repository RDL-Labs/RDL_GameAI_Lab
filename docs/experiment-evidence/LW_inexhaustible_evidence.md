# LW inexhaustible resource comparison

Baseline520755b. Added opt-in `--inexhaustible` to the timed-harvest runner. All eight resource patches remain available at their original locations; a successful pickup does not decrement stock. This is infinite supply, not seasonal regrowth. Work still lasts0.5s and completion checks reach/visibility/body; operation retries do not grant additional items. Stock mode is experimenter metadata, never an agent input. Finite stock remains default.

Initial seed20260928, sparse objects, skyline subrays, approach mode, three agents, initial stock12 per patch and control rules match the saved finite run. The existing cumulative acquisition cap96 per individual remains; unlimited World supply is not unlimited carrying/learning capacity. The run limit remains30 days or3 returned batches.

## Result

Current run completed at184.25 virtual seconds (day3 night), in1.773 wall seconds, on the third returned batch. C acquired96 and returned all96 in three batches. A/B acquired0. C learning records0, model_ref null; this does not demonstrate learned route improvement.

| C day | Inexhaustible patch (audit only) | Pickups | Total daily movement | First pickup within day |
| --- | --- | ---: | ---: | ---: |
| 1 | 6 | 32 | 36 | 8.00s |
| 2 | 6 | 34 | 30 | 7.00s |
| 3 | 6 | 30 | 28 | 5.75s |

All pickups were at the same physical patch. Patch number is an experimenter-side nearest-position attribution, not a location label given to the agent. Full daily movement traces are retained in the comparison JSON; movement includes exploration and return, not just one-way travel. Distances differ, so this is repeated use of the same place, not an identical trajectory assertion. Daily starting poses and retained state differ; shortening is not attributed to M_B.

Finite comparison (previous completed run) used patch6 on day1 (12 pickups,36 movement), patch3 on day2 (12,49), then patches7/2 on day3 (19,52). It completed30 days with60 total pickups and only2 returns. Compare the common first-three-day prefix rather than interpreting unequal run lengths as efficiency evidence.

C reached the unchanged cumulative96 acquisition cap on day3. That explains why day3 stops at30 acquisitions despite endless supply. Completion occurred on the third return, so no claim is made about behavior on days4–30 under this cap.

## Evidence and checks

`lightweight_inexhaustible.jsonl.gz` and `lightweight_inexhaustible_comparison.json` preserve the run, source hashes, initial-condition check, per-day movement traces and finite comparison. Two new tests PASS (13 distinct acquisitions without depletion, retry idempotence, default finite) plus four timed-harvest tests PASS. Full suite and Luanti not rerun.

Conclusion: keeping a resource available changes the observed use of space from moving between depleted patches to repeatedly harvesting and returning from one patch. Learned routing has not been established. A separate learning-use comparison or observation-boundary contract is needed before calling it learning.


## Thirty-day continuation without returned-batch stop

Added `--no-return-target` (API `stop_after_returns=None`); default remains three returns. Reproduction:

```powershell
python -m integrations.lightweight.timed_harvest --days 30 --skyline-subrays --inexhaustible --no-return-target --output integrations/lightweight/output/infinite30_no_target.jsonl
```

Completed all 30 days / 1920 virtual seconds / 23040 captures in 24.33 wall seconds. C still acquired 96 and delivered three batches; all agents had zero learning records and no adopted model. C daily movement/pickups were 36/32, 30/34, 28/30 on days 1–3, then 0/0 on every day 4–30. Its final pose stayed fixed. Each subsequent exploration phase had 124 `inventory_capacity` waits. World stock stayed 12 at every patch.

Removing the stop condition therefore did not expose continued harvesting routes: the unchanged Runtime cumulative acquisition cap blocks further exploration. This is not evidence of route convergence or learned optimization. World unloading and Runtime cumulative acquisition accounting remain separate. Altering that accounting is a separate change, not silently bundled into this stop-condition comparison.

`lightweight_inexhaustible_no_target.jsonl.gz` preserves the actual complete run; the corresponding `_audit.json` retains its SHA-256, manifest, summary, daily action reasons, movement traces and final poses for all agents. Focused stock/timed-harvest tests: 6 PASS. Full suite and Luanti not rerun.


## Confirmed unloading: continued harvesting over 30 days

The lightweight HarvestAgent now counts acquired operation IDs minus explicitly confirmed unloaded IDs. Capacity remains 96 carried items; cumulative Experience/results are never deleted. The shared ResourceExploration uses a count hook with its original cumulative default, preserving other integrations. Only the lightweight subclass admits unloading. Its adapter submits a delivery receipt after the corresponding body result has been accepted; the receipt binds a recorded waited operation/time and distinct, earlier successful pickup operations of that agent. Duplicate receipts are idempotent; conflicts, missing/foreign/already-unloaded items reject before mutation. This is a trusted local body adapter boundary, not a new network endpoint or canonical learning transition. Public lightweight inventory snapshots exclude unloaded items and retain separate unload receipts.

Same CLI as the previous section, with output `infinite30_unload_final.jsonl`: completed 30 days, 1920 virtual seconds in 23.885 wall seconds. C acquired and returned 1046 units across 30 returned batches; final carried count 0. A/B acquired 0. All learning records/model refs remain 0/null. Stock stayed 12 per patch.

| C days | Daily movement | Daily pickups |
| --- | ---: | ---: |
| 1 | 36 | 32 |
| 2 | 30 | 34 |
| 3–30 | 28 | 35 |

The full ordered movement coordinates match exactly across days 4–30. Thus continued harvesting and returning no longer stops at lifetime acquisition 96, but no continuing route variation or learned optimization emerged. Movement includes outbound and return legs. This one seed/initial condition is not a general convergence claim.

Saved complete evidence: `lightweight_inexhaustible_unload.jsonl.gz` and `_audit.json` (source SHA-256, manifest, summary, all daily coordinate paths and reasons). Two earlier execution attempts did not finish: Python 3.14 raised a TypeError in ray_hit; a Python 3.11 attempt exited 1 without diagnostic output. Those local logs remain separate; neither is counted as acceptance. Cause was not established. The subsequent Python run completed with exit 0 and its summary was verified before fixture creation.

Validation: timed harvest 5 PASS (including real acquisition/capacity stop/unload/next-day acquisition, preserved history, snapshot, retry and invalid receipt rejection), stock 2 PASS, legacy resource exploration 16 PASS. Full suite and Luanti not rerun.
