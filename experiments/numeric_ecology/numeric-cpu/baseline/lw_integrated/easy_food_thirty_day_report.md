# Thirty-day easy-food comparison

Started2026-10-14. Repetition pressure on in both cases; parent breadth off/on.
Same easy-food geometry, initial actors, body and learning rules as ten-day trial.
Only duration and inexhaustibility bound change:30 days and2,000,000 food units.
Supply exceeds all1,555,200 actor operations; no replenishment is required.
Ten-day/default runs retain the previous1,000,000-unit supply.

Output: `outputs/easy-food-thirty-day-1`. Each condition is one continuous World.
Runtime coefficients unchanged. Existing daily audit checks conservation, finite
bodies, actor operation counts and overnight continuity. A separate prefix audit
compares the first10 daily records against the earlier run after subtracting the
extra1,000,000 ground units; this tests that hidden excess stock did not change
the early life trajectory.

```sh
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/easy_food_experiment.jl SPEC OUTPUT 30 on
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/easy_food_audit.jl OUTPUT
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/easy_food_prefix_audit.jl TEN_DAY_OUTPUT OUTPUT
```
## Results (2026-10-14)

Both continuous 30-day runs completed: 1,555,200 operations each.
Daily conservation, finite body values, operation counts and overnight continuity:
358 assertions passed. First ten days match the earlier experiment after adjusting
only surplus ground stock: 22 assertions passed.

| Metric | Parent breadth off | Parent breadth on |
|---|---:|---:|
| Scenario time, seconds | 673.5041194 | 591.2780929 |
| Cumulative allocated bytes | 207215194391 | 215358211829 |
| Pickups A/B/C | 172/168/166 | 13/174/16 |
| Total pickups | 506 | 203 |
| Final shared stock | 425 | 168 |
| Consumed | 87 | 41 |
| Final reserve A/B/C | 92.278/88.991/91.711 | 0/90.041/0 |
| Completed individual nights | 90/90 | 90/90 |

Initial food 2,000,006 balances against ground, shared stock and consumption in
both runs; final inventories are zero. Off actors end near home. On A remains
at (-653.500, -3348.617), unchanged from day ten; C ends at
(6565.665, 1100.909). Zero reserve is not a modeled death claim.

On breadth levels total 210 low, 136 middle and 183776 full decisions out of
184122. Only 218 decisions restrict candidates; 688 candidates are removed
from 1965824 offered. Thus the intended sustained low-H narrow routine is not
established. Sleep completion alone does not imply adequate nutrition or return.

Combined scenario time is 1264.782 seconds (21 min 4.8 sec), excluding output
serialization and audit work. Different trajectories and first-call compilation
prevent interpreting the on/off timing difference as gate speedup. Allocation
figures are cumulative allocations, not resident or peak memory.

These are one seed and one easy-food layout. No coefficients were adjusted to
improve outcomes; parent breadth remains opt-in. The off condition supports
continued living in this case, whereas on A/C show a persistent unresolved
trajectory. Further diagnosis should locate early selection divergence and the
parent H/full-breadth regime, rather than merely extend the duration again.

## High parent-H diagnosis (2026-10-14; no runtime changes)

`lw_day/basic_loop.jl:resolve_method!` increments parent H by one for every
accepted `goal_value=false`, caps it at 32, and resets it only for true. There
is no time decay. Method success resets only method H. In `lw_day/run.jl`,
food goal success means picked_up/recovered; home success means observed home
within 1.25. Successful movement towards a goal still supplies false until
completion (except the phase-change evidence guard). Thus H here counts
uncompleted goal trials, not specifically failed progress.

Default threshold is 2. Admission exposes two candidates at H 0-1, four at
H 2-3 and all at H >=4. Full breadth does not require reaching the cap of 32.
A direct check using the actual BasicLoop functions confirmed four successful
movement results with incomplete parent goal produce H 1,2,3,4 and admitted
counts 2,4,4,6. All method H remain zero; arrival resets parent H to zero.
Four assertions passed; script saved under the experiment output directory.

Saved day-10/day-30 snapshots show on A and C have food H=0 and home H=32.
A home sequence remains 78109 at both dates; C grows 69579 to 78907 before
reserve reaches zero. B ends day 30 with both parent H zero. The reserve<=0
branch selects rest before the BasicLoop branch: forced rest does not start
a normal method trial and cannot clear the unresolved home H. Completed Sleep
also does not reset this H. These observations distinguish persistent stored H
from continuing active candidate comparison after bodily exhaustion.

High H also occurs without the admission gate (off B/C reach day-end H=32).
Therefore high H is not evidence that the easy environment itself is harsh,
nor does it alone explain the divergent trajectories. Short initial admission
restrictions can change subsequent experience, but the precise first causal
trajectory divergence has not been traced in this diagnosis. Daily event tails
retain at most 32 records per loop and repeat unchanged tails across days;
they must not be counted as independent new experiences.

Conclusion: the current parent signal and admission threshold make even normal
multi-step completion rapidly reach full breadth. Baseline-temperature changes
are deferred. Before changing coefficients, distinguish ongoing progress,
observed failure/stagnation and final completion in the parent appraisal contract.

## Return-approach trace (2026-10-14)

Re-executed the first five days of the exact on-spec, changing only duration and
adding read-only pre-operation CSV instrumentation via an in-memory replacement
of lw_day. All five daily records exactly match the original 30-day result.
Trace and instrumentation script: outputs/easy-food-thirty-day-1/return-approach.csv
and trace_return.jl. Production runtime unchanged.

Failed return episodes: A day 3 starts at 43200 simulation seconds, distance
13.3566; nearest approach is 8.83276 at 43220. It never enters radius 2 and
crosses range 60 at 43341. C day 5 starts at 77760, distance 13.6223; nearest
approach is 1.4397666 at 77829. It has six observations within radius 2 but none
within the arrival radius 1.25. It crosses range 60 at 77950.

C retains heading 135 degrees across approach and departure:
77827 distance 1.8426, visible; 77828 1.5761, visible; 77829 1.4398, visible;
77830 1.4703, not visible; 77831 1.6585, not visible; 77832 1.9594, not visible.
Home H is already 32 throughout. The commands continue straight (direction 2),
then use reposition_0. This is a near miss followed by departure, not repeated
small putts across the arrival circle. Loss of visibility occurs at short range
because the home is behind the heading, not because distance has exceeded 60.

Code inspection: inertia_candidate! checks food visibility, hazards, feasible
forward movement and repetition, but receives no home observation or home-distance
progress. inertia_view likewise contains no direct home beacon. Inertial continuation
retains method identity while emitting direction 2 and question movement_progress;
physical movement can therefore succeed while moving away from home. These are
concrete missing goal-relative checks, but the trace does not record every candidate
score or inertia flag, so it does not isolate the contribution of every evaluator.

A radius of 1.5 would classify C's recorded nearest approach as arrival, but that
counterfactual policy was not run; A would still not qualify. Thus widening arrival
alone is not a demonstrated general fix. Prioritize goal-relative approach/overshoot
review while distinguishing it from successful bodily movement. No radius, H rule,
or baseline temperature was changed in this investigation.
