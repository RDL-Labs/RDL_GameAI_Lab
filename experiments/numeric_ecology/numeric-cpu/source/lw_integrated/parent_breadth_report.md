# Parent H candidate breadth — finite LW connection

2026-10-14. Opt-in native option: `--parent-breadth on` (default off).
Frozen specs use `config.parent_breadth = "on"`.

## Contract

The current food/home BasicLoop is the parent of its method candidates.
Its unresolved H controls admission to subsequent energy, harvest, Sleep,
body, bundle and trail candidate evaluation:

|Parent H|Maximum admitted candidates|
|---|---:|
|H < threshold|2|
|threshold <= H < 2 threshold|4|
|H >= 2 threshold|all currently generated candidates|

H saturation at 32 always admits all, including thresholds above 16.
The low/middle stages prefer methods used in the last 32 accepted results,
then current proposal priority, then method ID. Use frequency is not success
credit. Existing method H still evaluates the admitted methods. Unknown results
do not artificially increase parent H; the existing parent result contract applies.
Parent success resets H via the existing resolver and narrows the next admission.

Only presently generated candidates can be admitted. No hidden direction or
unobserved target is invented. Empty input remains empty. The function is read-only.
All downstream counterfactual diagnostics use the same admitted set.

Emergency/body priority handling, direct pickup and deposit, and valid movement
inertia execute before this gate. They retain their existing authority. The gate
does not postpone danger until H increases or end a parent purpose.

## Scope and cost

This is candidate **width**, not recursive memory depth. It is connected to
food/home method selection, not every social or safety M_B. No new biology claim.
Candidate generation and observation still run. Admission scans the finite
generated set, maintains at most 2/4 entries, and reads at most 32 prior results.
It reduces candidates submitted to downstream evaluators; it does not eliminate
all history scans inside those evaluators. The 2/4 thresholds are initial explicit
experiment parameters, not a universal RDL law or a performance guarantee.

`parent_breadth` diagnostics count decisions, offered/admitted candidate entries,
restricted decisions and low/middle/full levels per actor. They are counts of
evaluation opportunities, not measured CPU savings or independent learning events.

## Validation

Standalone contract: 11 assertions passed (stages, saturation, familiarity,
read-only behavior, feasible-set membership, empty/single candidates, successful
reset, and failure-driven widening). Added to the existing manual LW-loop workflow.
The one-day off/on experiment uses the same saved riparian World and existing
integrated loop; per-mode resource conservation, 51,840 operations and finite body
values are asserted. Evidence: `outputs/parent-breadth-1`.

Both runs completed; 9 integration assertions passed. Enabled: 10,036 gate
decisions, 161 restricted decisions; 107,973 offered vs 107,489 admitted entries
(484 fewer, about 0.45%). Full-width level occurred 9,842 times (about 98%).
This parent goal remains unresolved during much of travel, so high H and broad
evaluation dominate. No threshold tuning was used to manufacture cost savings.
Both food totals: 124 = ground 112 + shared 5 + held 2 + consumed 5.
Sleep A/C completed, B pending in both.

Off/on call times were 37.480/19.925 seconds with 12.576/9.748 GB cumulative
allocation. Off ran first with compilation in the same process; paths can differ.
These numbers are NOT a speedup estimate attributable to the gate.
The disabled result, excluding the new null diagnostic key, was independently
compared to the saved pre-change one-day result and matched exactly. Full Python
suite and cloud CI were not run for this experiment.

Commands:

```sh
julia experiments/julia_migration/lw_integrated/parent_breadth_checks.jl
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/parent_breadth_experiment.jl SPEC_JSON OUTPUT
```
