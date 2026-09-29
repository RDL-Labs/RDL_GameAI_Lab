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
