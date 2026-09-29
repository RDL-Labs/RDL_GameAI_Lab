# Home-purpose landmark search

Baseline 84bb69b. Lightweight timed-harvest now uses `runtime.home_search.review` through a return-review hook. Other DayCycle integrations keep the existing homing implementation. The return phase keeps purpose `find-home-appearance`; this does not select Food, adopt a route model, or access World coordinates. After four unsuccessful home scans (or blocked homing), observed-landmark exploration can select a currently observed patch. Each new observation checks for home appearance first and resumes homing if one unambiguous patch appears. Near appearance remains only home-like evidence, not proof of delivery.

Budgets: existing 24-second return phase, 64 homing operations, plus at most 32 search body operations per day. Existing landmark limits of eight goals, twelve operations per goal and four no-candidate scans remain. Search budgets persist across search/homing switches; no repeated budget renewal. Missing body correspondence/home memory cannot authorize search. Incomplete observations cannot invent landmarks. At night all search movement stops under the existing phase authority; unresolved return is recorded at deadline. Search is initial observed control, not M_B route learning or canonical T1.

## Thirty-day actual lightweight run

Same enabled-M_B experiment: sparse seed20260928, three steady agents, finite resources until genuine adoption at 76.75s, then remaining resources inexhaustible; no three-return termination. Completed 30 days in 52.40 wall seconds. Saved log and audit: `lightweight_home_search.jsonl.gz`, `lightweight_home_search_audit.json`.

C day3 transitions (absolute virtual seconds): 161.00 searching; 164.25 home-appearance homing; 166.50 searching; 170.00 homing; 172.25 searching. These are appearance matches, not verified tower identities. Thus search and reacquisition both occurred in the actual World, without a destination coordinate. C total day3 movement increased from baseline 50 to 87. Day4 movement was 11; days5–30 zero. Extra movement alone is not improvement.

Final outcome remains 120 pickups, two returned batches/24 delivered, 96 still carried, 108 learning records and the same adopted C model. No later delivery was obtained. Search can exhaust available observed candidates and wait; this experiment does not demonstrate recovery from all lost conditions. Resource holding capacity remains valid and is reached on day7. A/B still have no harvest or model.

Reproduction:

```powershell
python -m integrations.lightweight.timed_harvest --days 30 --skyline-subrays --no-return-target --inexhaustible-after-model --mb-field-mode enabled --output integrations/lightweight/output/home_search30.jsonl
```

Tests: home search 4 PASS (observed target provenance, immutable inputs, reacquisition priority, preserved budgets, missing body/home rejection and incomplete observations); timed harvest 5 PASS; legacy day cycle including saved Luanti replay/retry 6 PASS. Total 15 PASS. Full suite and live Luanti not rerun.
