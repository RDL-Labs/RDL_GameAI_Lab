# Observed-target approach: finite adaptive resolution

Implemented 2026-10-14, opt-in config `adaptive_approach: on` (default off).
Shared food/home path. Uses only the currently observed relative target vector.
Within 16 units, bypass inertial continuation and re-evaluate existing candidates.
If the selected walk sector is within 22.5 degrees of the observed target bearing,
refine its angle to that bearing; other selected sectors remain unchanged.
Limit displacement to min(normal walk span, distance minus 1.0). Arrival/pickup
radius remains 1.25. Fine direction receives a fresh local collision and resistance
sample, with body feasibility checked; the execution checks collision again.
Short steps retain full walk effort per operation (conservative, not a calibrated
energy-by-distance model). Coarse ground prediction correspondence is marked
non-comparable for refined steps. H, thresholds, Sleep and food rules unchanged.
This is a finite locomotor resolution adapter, not a general rho framework.

Validation: approach_checks.jl 10 assertions passed (angle/step refinement,
absent/far/already-arrived targets, other sectors, blockage, body limit).

30-day comparison started with the previous easy-food geometry and 2,000,000
units; repetition pressure on, parent breadth off/on, adaptive approach on in
both. Previous saved 30-day results supply the no-approach baseline.
Input: outputs/approach-thirty-day-input.json.
Output: outputs/easy-food-approach-thirty-day-1.
Run session 52307. After both conditions complete the wrapper runs the existing
daily conservation/continuity audit. Results pending; no outcome claim yet.

This initial comparison combines near-target inertia bypass and sector/step
refinement. It cannot separately attribute effects to those components.

Retry outcome: 2026-10-14 11:34 JST, exit 1. Off completed in 346.4526257
seconds (489 pickups, shared stock408, consumed87, all90 nights completed).
On crashed before result persistence with EXCEPTION_ACCESS_VIOLATION at Julia
arg_tuple / jl_method_error, during movement_observation dictionary construction.
This differs from the first crash stack (update_ground! / type lookup).
Cause is undetermined. Combined post-run audit was not executed. Off outputs
and full retry crash log remain saved; no on outcome or improvement claim.
Five-minute monitor paused after failure. No further run started.
