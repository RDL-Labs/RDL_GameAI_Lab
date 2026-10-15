# B1a: goal/method loop and three-day continuity

Status: **finite implementation / behavioral checks passed**. Not full LW parity.
Code `984f3f973e60ca017be33c30414901a3846ec4c8`,
[run 38248947466](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38248947466).
Julia1.13.1, Ubuntu24.04, human_scale_v1, one thread. Baseline 7b03a0a.

## Reusable part

`BasicLoop` separates goal identity/parent reference, goal H, method H/threshold,
current candidates, selection, accepted result and re-selection. The adapters
supply operational questions and evidence; the kernel has no World coordinates.
Food and home use the same kernel. A third arbitrary goal name is tested locally,
not claimed as another implemented behavior. Method success cannot reset parent H
without separate parent confirmation; missing comparison defers.

Current feasible candidates only. Parent H opens alternative steps; method H
reduces their priority. If every available method is unresolved, least recently
tried candidates are reconsidered. This permits continued selection at bounded
H saturation. It does not promise success, optimality, novelty or a new route.
No lifetime action quota; no daily reset. See [contract](contract.md).

This is a small implementation of roles from existing LW continuous selection,
nested local models and goal difference. Full skyline/route memory and navigation
remain unported. Parent references are not arbitrary recursive goal replacement.
Food/Sleep relation learning and social-policy generalization remain separate.

## Verification

- 49 kernel assertions: goal/method separation, changed choice after nonconfirmation,
  defer, wrong source, unaccepted result, duplicate/conflict handling, independent
  goals, current feasibility, and continued method reconsideration at H=32.
- 17 lifecycle assertions: 3 days × 3 agents × 2 scenes; 155,520 operations per scene,
  endpoint/start continuity on both day boundaries, food conservation, every
  night completed, return-phase walking, movement continuing on days2/3.
- Separate private-stock control verifies retrieve followed by eat.
- Every simulated second also asserts resource conservation.

Position, yaw, body, carried/private food, social count/model and method/goal H
match exactly between each recorded night endpoint and next morning start.
World/resources are not reconstructed. Only the next Sleep cycle is initialized.
Normal three-day runs also exercised retrieval/eating of the previous day's stock.

| Scene / actor | Successful pickups (3d) | Final private food | Final carried | Final reserve |
|---|---:|---:|---:|---:|
| social_shared A | 4 | 2 | 0 | 91.89 |
| social_shared B | 4 | 5 | 0 | 92.80 |
| social_shared C | 4 | 3 | 0 | 91.62 |
| lw_sparse A | 13 | 11 | 0 | 92.77 |
| lw_sparse B | 0 | 1 | 0 | 92.18 |
| lw_sparse C | 0 | 0 | 0 | 72.59 |

All six final positions are within the provisional 1.25-unit home contact range.
This is this run's result, not a required all-return success criterion.
social_shared food: 16 = ground0 + carried0 + stored10 + consumed6.
Sparse food: 100 = ground83 + carried0 + stored12 + consumed5.
B/C initially held two units; stored totals are not all newly harvested.
Successful pickup counts were reconstructed from action/status event intervals.

In social_shared all agents deposited on day1 and retrieved one unit on day2.
In sparse A found 13 units on day2 and deposited twice; A/B retrieved on day2.
C acquired none. Aid records at end: social_shared A8/B0/C0; sparse A8/B0/C1.
Local aid Sleep consolidation continues; no ablation here establishes its causal
effect on next-day choices. Harvest Sleep remains insufficient evidence.

## Failures and limits retained

Run 38248493881 failed before tests on ambiguous Julia `3.+alignment` syntax;
corrected to `3.0 + alignment` without changing arithmetic.
Run 38248673592 passed 60 assertions but exposed behavioral failure: all methods
reached the bounded penalty, restoring survey's higher base score permanently.
Days2/3 had no walking. The least-recent unresolved rule and a saturation test
were then added. The final run passes 66 assertions and walking continues.

B0 one-day counts are saved for diagnosis, not a matched performance comparison.
Three-day movement totals remain large (roughly 10,000 world units per agent).
Continued movement does not establish exploration efficiency or absence of loops.
No maximum excursion/map audit was collected. Do not claim this solves all spatial
stagnation. Full learned landmark/route behavior is the next missing adapter.
No full suite, long campaign, Python trace parity or whole-LW speed claim.

Artifact `julia-lw-loop`: inputs/source hashes, raw compact transitions,
daily/start/terminal snapshots, counts and stdout. ZIP SHA256:
`e28263965552d9dcffb9df7f50db19fa78f54d1af1947e7c927fa499aa8d6619`.
