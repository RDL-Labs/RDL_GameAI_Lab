# Reusable goal comparison and food-search integration

Baseline d871986. `goal_difference.initial` now takes a goal ID, fixed local interpretation model reference, comparison dimension, threshold and optional parent goal reference. `begin` freezes that contract and source observation for a trial. `finish` compares under the frozen dimension, defers missing evidence, retains unresolved residuals, resolves on confirmation, and preserves trial records. Active trials cannot be overwritten, closed trials cannot be reopened; duplicate closure is idempotent and conflicting closure rejects. `method` selects between caller-supplied permitted methods without itself granting body authority.

Home and Food share this mechanism but have separate state. Both reference an agent-local food-security parent as metadata. **No parent evaluator or recursive hierarchy scheduler is implemented**; child H values are not added together or promoted into parent H. This is a reusable two-goal pilot, not implementation of every goal or arbitrary nesting. These fixed goal hypotheses and supplied methods are not canonical reconstructed M_B or T1. Existing adopted harvest M_B remains independently sourced.

Food contract: expected one or more accepted acquisitions during the active daily exploration trial; F dimension `food_acquired`, fixed model `food-trial-acquisition-hypothesis-v1`. At next morning, successful accepted pickup confirms. Otherwise comparison requires actual result/packet records, complete Food coverage and no stale/expired result in the trial interval. Incomplete evidence defers. This states only failure of the finite trial to acquire food, not absence of food in World. Days spent on pending home purpose do not open Food trials or add Food E. Day30 remains open until a further observation; no synthetic end result.

Food method threshold2 selects bounded rescan only when enabled. It can replace an existing landmark no-candidate/goal-budget/operation-budget wait with at most four 90-degree turns per day. It cannot override pickup, body correspondence, carrying capacity, return priority or night. It does not invent an unseen target, grant translation, reset landmark budgets, or promise escape. Other goals may supply different evaluation/response contracts. New flag `--food-goal-mode enabled|disabled` defaults disabled; home comparison switch remains separate.

## Paired 30-day experiment

Same sparse seed20260928, three steady agents, confirmed unloading, adopted harvest field enabled, home residual method enabled, initial finite stock followed by inexhaustibility after actual adoption. Only Food method switch differs.

Both arms: 67 acquired and delivered in four batches; C adopted model and home recovery match baseline. Enabled produced 196 actual `food_goal_rescan` commands across A/B/C, disabled zero. Complete log audit checked every rescan is a 90-degree turn in exploration, home not pending, Food H>=2, and counter<=4.

C: days4–6 Food H stays0 during return priority while home H reaches1/2/3. After return, home H resolves0. No harvest on day8 gives Food H=1 at day9; day10 Food H=2 and four rescans occur. Days10–30 have four rescans/day but no new translation or pickup; day30 Food H=22, home H=0. This demonstrates separate goal residuals and real method action changes, **not improved exploration**. A rescan alone cannot create a new observed route. No threshold/coefficients were tuned to force success.

Both runs completed exit0, 1920 virtual seconds; enabled64.97 wall seconds, disabled66.14 (not a performance comparison). Artifacts `lightweight_generic_goal_enabled.jsonl.gz`, `lightweight_generic_goal_disabled.jsonl.gz`, `lightweight_generic_goal_comparison.json` preserve full traces, hashes, manifests, summaries and per-day goal residuals/paths. Run timed_harvest with the preceding paired command plus `--food-goal-mode enabled` or `disabled`.

Validation: generic goal tests4, home search6, timed harvest5, all PASS (15 total). Full suite/live Luanti not rerun.
