# Body-linked local ground models and exploration

Code f633b18. Reference runtime/ground_continuity.py and its integration in
continuous_selection.review. Same native LW loop, opt-in --ground-continuity on
(requires --ground-perception on).

Measured per-operation translation and yaw transform prior actor-relative points.
Native receipts bind actor, previous observation and before/after ticks, with one
accepted physical operation per actor per tick. This is a synchronous replacement
for the Python pose/revision transport binding, not an asynchronous receipt port.
No complete World position is stored in the agent model.

Two sampled overlaps within0.6 and unique assignment on both sides preserve a
model. Ambiguity withholds support. Missing correspondence retires old models.
Models expire after8s unseen; bounds are8 models,32 points/transforms,16 links/sources.
Grass contradicting previous worn samples is context_changed; occlusion is unknown.
Neither provides a current proposal. Current supported endpoints only, no unseen
path extrapolation. Native integer observation references differ from Python hash
references without changing this relationship contract.

As of 2026-10-22, ordinary movement selection may add the existing2.25-priority
ground method for both food and home purposes, including when a target is visible.
There is no exploration/return phase restriction. Only currently feasible walk
directions are proposed. Danger, eating, pickup, at-home deposit and rest gates
still run first; an accepted movement-inertia continuation retains its existing
fast path. A path is an option, not a guarantee of reaching the current goal.
Ground methods enter
the existing BasicLoop with their own H. Successful extension requires actual
performed movement and a current same-model extension; it does not resolve the
parent food goal. Native walking combines turn and step, unlike Python's separate
commands, using the measured combined transform.

This is tentative local M_B use, not a canonical T1 adoption or a map to food.
The 2026-10-22 shared local structure model adds a current-component check before
path proposals: disconnected sampled components are not followed as one band.
See [structure_report.md](structure_report.md) for ground/water/obstacle grouping,
sampled breaks, unknown intervals and the remaining movement-integration boundary.
Initial cloud verification38349527774:41 checks PASS. Three days,seed20261005,
renewable food,wear/patches/perception,155520 operations per condition,all9 Sleep
cycles. Off stores A35/B59/C35; on A72/B83/C29. On ledger100+126=36+184+6.
Ground selections A1978/B1855/C1816. These count selected methods, not successful
extensions or distinct roads. Different replenishment and mixed individual outcomes
prohibit a general efficiency claim.

Long-run review found2755–3042 food method nodes left after ground model retirement.
Code8f2ce14 removes retired ground method nodes only AFTER pending result resolution.
Model sequence IDs never recur, so these nodes have no future candidate authority.
Active model H and bounded diagnostic events remain. This storage-lifecycle
adaptation differs from Python's indefinitely retained method dictionary; it is
explicitly for long-run capacity, not forgetting an active failed alternative.
Follow-up run38349924115 passed42 assertions. Independent old/new saved-result
comparison, removing only ground method-node maps, is exactly equal in both
conditions. Final food method nodes are A18/B15/C14, previously3037/3042/2755.
Per-night ground nodes are bounded by8. No general performance claim.


## Current-support evidence correction

`fb96c5e` aligns the ground-extension comparison with Python continuous_selection:
unobserved, context-changed, missing or retired model support returns null, not
false. Observed non-extension or no actual movement returns false; a current
extension plus performed displacement returns true. Method H therefore remains
unchanged when comparison is unavailable; parent food/home evidence stays separate.

[Run 38359535766](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38359535766)
passed 57 assertions, including 11 explicit three-valued/H/replay checks.
Three days per condition, seed20261005,155520 operations each. Independent saved
summary conservation checks:

* off: food 100+95=60+stock129+carried0+consumed6; Sleep 9/9.
* on: food 100+108=42+stock160+carried0+consumed6; Sleep 9/9.

This deliberately changes unsupported-evidence behavior; historical on results
above remain historical, not updated to pretend exact equivalence. No efficiency
improvement or full-backend readiness claim.
