# Composed lateral tendency migration — in progress

Reference: runtime/composed_lateral_bias.py, applied after calculate_terrain and
model_movement_field in timed_harvest.ExperimentAgent._calculate_current_terrain.

The exact component gate is ported in lw_day/lateral_bias.jl. A Python-generated
56-case oracle and113 local Julia assertions pass (2026-10-14): both sides,
per-component0/.099/.1/.100000002/.5 differences, forward-minimum priority,
incomplete acquisition, excluded direction, caller-input isolation and invalid
neutral. Test command: julia --project=experiments/julia_migration/julia
experiments/julia_migration/lw_integrated/lateral_checks.jl.

This is not yet connected to native life. Current movement_observation exposes
food, acquired ground rays and body energy rows, but lacks the bounded observed
obstacle point channel used to calculate Python terrain repulsion. Energy cost
or overall candidate priority cannot stand in for the five separate components:
physical,food,obstacle,model_field_cost,total.

Next dependency: finite body-relative obstacle observation and appraised terrain
components, with incomplete coverage suppressing lateral scoring; then an opt-in
native lateral_side adapter. Preserve the current feasible candidate set and
priority interrupts. Do not pass World obstacle centers or a global map directly
to the decision policy. Complete default-disabled regression and enabled living
checks before marking this optional Python setting covered.


## Native connection follow-up (2026-10-14)

The prior disconnected status is superseded: --lateral-side off|left|right now
connects seven finite obstacle rays (12-unit range, no object IDs/centers),
current acquired ground and visible taught-food points to appraised components.
Incomplete observations suppress the gate. Only existing walk candidates receive
the bounded priority delta; no feasibility override or new candidate is added.
The adopted harvest model's existing approach contribution participates in the
component gate. Higher-level priority branches and continuing inertia remain above
this adapter. The policy receives ray evidence, not hidden World geometry.

Declared adaptation: native candidates use priority rather than Python terrain
minimum steering, so only lateral cost is projected into that existing selector.
Terrain food/obstacle/height formulas supply eligibility; they do not replace the
whole native method ranking. Float64 sum is used, not Python math.fsum, so full
floating terrain parity is not claimed. The gate itself matches56 Python cases.

Eleven connection checks pass: finite rays, no hidden fields, rear exclusion,
left preference, unchanged candidate membership, partial suppression, blocked
exclusion and invalid configuration. One native day completes51,840 operations,
conservation100=79 ground+17 held+4 consumed, with applied gates A17/B11/C328.
These counts are applications, not evidence of improved behavior or selection
changes. Disabled frozen one-day output is byte-identical to the preconnection
output. Right-enabled living replay and broader combined coverage remain pending.


## Composed right-side verification

Right-side, threshold3 and all compatible campaign features completed one day
plus frozen replay locally. Existing safety20, integrated invariants4, right-life5,
and replay1 assertions passed (30 total). Independent saved audit also passed
51,840 operations, daily/terminal conservation and final physical correspondence.
Result bytes match replay. This verifies connection, not universal return success.
Connection unit checks were expanded to13, including cancellation between model
and physical components (not eligible) and run candidates (unchanged).
The30-day baseline remains the off-handedness configuration; optional handedness
was tested in shorter integration rather than claiming it had already run30 days.
