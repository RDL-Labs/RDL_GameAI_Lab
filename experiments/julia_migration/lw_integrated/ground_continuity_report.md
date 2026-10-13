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

Exploration with no current food target and no active return purpose may add the
existing2.25-priority ground method, using only currently feasible walk directions.
Danger, eating, pickup, return and rest gates still run first. Ground methods enter
the existing BasicLoop with their own H. Successful extension requires actual
performed movement and a current same-model extension; it does not resolve the
parent food goal. Native walking combines turn and step, unlike Python's separate
commands, using the measured combined transform.

This is tentative local M_B use, not a canonical T1 adoption or a map to food.
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
Follow-up run38349924115 pending; old/new behavior will be compared separately
from obsolete-node diagnostics.
