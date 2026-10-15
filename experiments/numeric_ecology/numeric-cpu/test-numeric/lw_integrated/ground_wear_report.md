# Shared World ground wear and recovery

Implementation: 3374099, corrected reference coupling a955b9a.
Reference: integrations/lightweight/ground_wear.py and energy_exploration.py.

`--ground-wear on` joins the existing native/run_integrated/lw_day path. Default
off preserves old behavior. Actual performed walking deposits distance into
one-unit cells, sampled every at most0.1 units. Failed movement and turning do not
create wear. Running/climbing do not use the walking-only Python wear effect.

Resistance is `1 + (base - 1) * (1 - 0.5 * min(1, wear/10))`.
After one day without walking, wear recovers by2 units per day. Lifetime distance
and per-actor distance remain observer diagnostics; recovery does not erase history.
Local five-direction resistance samples feed existing method evaluation and body
execution. Agents receive no cell map or other actors' complete trajectories.

Recovery is evaluated lazily when a cell is sampled, walked, or exported, using
its last update and last walking time. This avoids scanning the whole map on every
second while preserving the reference elapsed-time rule. Receipts are bounded to
one per actor at the current World tick; replay matches, conflict rejects, and
old-tick submission rejects. This synchronous adapter is not asynchronous transport.

Candidate ranking now allows the already-observed resistance improvement below
baseline1.5 to contribute, instead of clamping that benefit away. All old ground
conditions have resistance>=1.5 and therefore retain their previous formula.

Different actors execute sequentially after a common observation. Another actor
may modify a sampled cell before execution. Body comparison requires the same
resistance in addition to existing load/clearance checks; changed material is not
reported as a prediction-calculation mismatch.

Final cell map is observer-only in result/summary. Ground appearance and pattern
recognition remain the next separate integration boundary; this does not claim
an agent recognizes a road or knows its destination. Water/landscape surfaces
are not yet present in this native World.

## Verified result

Corrected code a955b9a, Actions run38348128115:41 assertions PASS
(safety16, wear13, two integrated runs8, living ground4).
Earlier run38348047045 used the superseded resistance multiplier and is not the
acceptance baseline.

Seed20261005, three days, three actors, renewable food, patches, Sleep apply/strata.
Each condition completed155520 operations and all9 Sleep cycles.

| Metric | Off | On |
|---|---:|---:|
| Initial food |100|100|
| Added food |90|95|
| Ground food |36|36|
| Stored A/B/C |32/53/63|35/83/35|
| Consumed |6|6|
| Carried |0|0|
| Actual walking distance |30433|31805.5|

Food conserves in both. Different replenishment totals prohibit an equal-resource
efficiency claim. Individual outcomes change in both directions.

Enabled World:63611 accepted walks,1248 touched cells,432 cells at wear>=10 at
termination. Sum of lifetime cell distance equals actual walking distance.
All comparable body-delta mismatches zero. Final map is in result.ground_wear.cells.

Measured scenario calls47.52s off(first compilation),34.58s on; these are not a
warmed paired performance comparison or a memory benchmark.

No full repository suite,30-day acceptance,ground-pattern recognition or canonical
T1 claim is made. Native ground is still the existing sparse obstacle/patch World.
