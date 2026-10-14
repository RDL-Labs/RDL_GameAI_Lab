# Finite lack-of-change pressure in LW

2026-10-14. `--repetition-pressure on`, default off. Frozen spec key
`config.repetition_pressure`. Existing integrated loop; no new World simulator.

## Contract

Actor-local residual per method (at most64 methods, H in[0,32]). Consecutive
same-method results with equal coarse view add1 if no actual translation, strain
recovery, burst recovery or listed resource event occurred. The view contains
phase, purpose family, observed direction clearance/status and visible food
appearance/rounded distance. It is not a World map or hidden food position.

Residual decays0.1 per simulated second, including intervals outside selection.
At H>=4, the method priority is reduced by min(4,H/4). No candidate is generated,
forced or deleted. The method may still win. The threshold/decay are explicit
finite initial coefficients, not a biological model or Core E/H replacement.
Task-success H remains separate, so `rested=performed` does not erase this residual.

Only exploration/return actions with a method identity accumulate. Automatic
night/orientation/safety actions break the chain; their existing authority is
unchanged. Completed recovery suppresses addition, not all future boredom forever.
Visible changes break equality; a resource change suppresses addition. Translation
suppresses addition even with similar views; successful repetitive travel is not
yet covered. Stationary scans may count when coarse observations stay the same.
This initial view does not include every modality and is not a general novelty model.

The per-method residual persists across purpose changes while decaying; the
phase/family change breaks consecutive accumulation. It is actor-local, not an
independent residual per parent edge. Source/last timestamp retained; duplicate
or out-of-order timestamps are rejected, not counted twice. Internal loop delivers
one result per actor-second; no new network replay API is claimed.

## Verification

10 unit assertions: accumulation, priority change without candidate growth,
ordering rejection, real improvement, changed view, elapsed decay and chain reset.
Added to the manual LW-loop workflow. One-day off/on comparison uses the previous
nearby inexhaustible-food scene with parent breadth enabled in both cases.
Checks operations/resource conservation and actual pressure/selection changes.
Evidence: `outputs/repetition-pressure-1`.

Both modes completed51,840 operations; all7 integration assertions passed.

|Metric|Off|On|
|---|---:|---:|
|Pickup A/B/C|0/0/0|7/0/4|
|Walk A/B/C|18/17/15|1,299/4,796/1,120|
|Rest A/B/C|17,256/17,257/17,259|15,736/10,436/15,751|
|Final shared stock|3|14|
|Consumed|3|3|
|Sleep complete|3/3|3/3|

On: additions A212/B1607/C348; same-state choices changed by the repetition
projection A380/B4770/C625. These are decision counters, not independent trials.
The field applies after other contributions and before final selection, so this
comparison isolates its immediate choice effect, not long-term causal efficiency.
Stock conservation on:1,000,006 =999,989 ground +14 shared +3 consumed.
All final inventories zero. Rest-dominated behavior broke without commanding
exploration; B travelled but did not acquire food. This single scene/day does not
establish robust exploration or optimized efficiency. Automatic night rest remains.

Call times off27.565/on15.992 seconds, fixed-order same process; compilation and
different trajectories preclude a speedup attribution. Full suite/cloud not run.
