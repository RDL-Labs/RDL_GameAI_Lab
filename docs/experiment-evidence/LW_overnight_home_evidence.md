# Overnight unresolved home purpose

Baseline a5ca226. Lightweight timed harvesting retains `home_pending` when a day's return remains unresolved, or cargo remains undelivered. The next day's scheduled exploration period becomes return-purpose search; orientation and night still wait. Cargo, observations/results, adopted model and prior night records remain intact. A confirmed unload receipt or home-like observation with no outstanding cargo can clear the purpose at the next morning. An appearance match alone cannot clear undelivered cargo. No position reset, automatic cargo delivery, hidden home coordinates or canonical Sleep is added.

Every morning starts a fresh finite search attempt (same per-day budgets); the attempt seed includes day and agent seed so candidate selection need not always draw the same index. This is initial control, not learned avoidance of failed landmarks. Previous night records are retained, but are not a learned route map or a semantic blacklist. With no usable observed candidates an attempt can still wait until the next morning. Thus ongoing daily reconsideration is implemented, not guaranteed continuous movement or eventual recovery.

DayCycle gets a default-preserving phase hook; only lightweight HarvestAgent overrides it. Search/homing keeps its prior daily limits and night boundary. Confirmed unloading takes precedence over an unresolved appearance-only return result, as checked by the existing capacity/unload/next-day pickup regression.

Reproduction:

```powershell
python -m integrations.lightweight.timed_harvest --days 30 --skyline-subrays --no-return-target --inexhaustible-after-model --mb-field-mode enabled --output integrations/lightweight/output/overnight_home30_final.jsonl
```

Focused verification: home search 5 PASS, timed harvest 5 PASS, legacy day cycle including saved Luanti replay 6 PASS. Full suite and live Luanti not rerun.


## Actual 30-day outcome

Completed 1920 virtual seconds in 43.62 wall seconds, exit 0. C acquired 43 units, delivered 24 in two batches, and retained 19 carried. It retained 31 learning records and its adopted M_B. A/B harvested zero. C failed to return on day3; days4–30 have `home_pending=true` and zero pickups. Movement was 42 on day4 and 44 on every day5–30. Every night command was wait; every pending-home decision was non-pickup, checked from the complete log. Thus daily home exploration resumed rather than saturating inventory with additional Food.

Return success did not improve. Ordered movement coordinates on days5–30 are identical: True. Daily resumption alone does not demonstrate learning from failed searches or escaping a repeated route. That remains a separate unresolved behavior.

Saved `lightweight_overnight_home.jsonl.gz` and `_audit.json` contain the source hash, summary, daily phases, pending status, movement paths and reasons. The earlier pre-fix run is retained locally and is not the acceptance artifact.
