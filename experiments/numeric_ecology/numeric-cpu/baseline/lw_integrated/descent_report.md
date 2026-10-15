# Continuous local descent: first finite comparison

2026-10-14. Initially opt-in; newly generated native runs now default on (see Adoption). Pure local_descent
accepts current relative target and seven-ray local obstacle observations only.
Unit attraction toward target plus bounded radial repulsion from hits within
3 units; zero resultant or incomplete obstacle observation supplies no vector.
This is a new finite potential approximation, not mathematical equivalence to
all existing L15A sampled costs or a full migration of every M_B field.

Integration is a locomotor adapter for selected ordinary step_* walk methods.
It replaces the coarse sector angle with continuous resultant bearing. Other
methods (rest, survey, reposition, climbing, routes) retain their own behavior.
Visible targets interrupt inertial continuation; hidden targets are not supplied.
Collision/body checks sample the proposed segment and execution rechecks it.
If refined direction is infeasible, the original selected feasible action remains.
Shortening keeps full walk effort. Target remains the observed home beacon or food;
tower location is not secretly substituted for home. H and arrival1.25 unchanged.

Tests: pure local descent6 assertions; one-day daily audit10 assertions.
Comparison: same approach_spec, days1, parent breadth on, adaptive approach on.
continuous_descent off/on. Actual pre-operation traces saved for all three actors.

| Condition | Pickups A/B/C | Shared stock | Reserve A/B/C |
|---|---|---|---|
| existing approach |1/7/1|12|90.688/90.278/90.676|
| continuous descent |1/1/1|6|90.697/90.715/90.722|

Both end with all three actors near home. No claim of better harvesting or general
return reliability. Call times27.335/11.558sec are not a speed comparison: first
includes compilation and trajectories differ. No30day run was conducted here.
Outputs: outputs/local-descent-one-day-1. GUI gui-p5/julia-trajectory offers both
actual one-day traces plus the older pre-approach failure trace. Continuous
headings can differ from displayed coarse method ID; method identity is retained
for this finite adapter, so it is not yet a general continuous candidate ontology.

## Adoption

Continuous direction is adopted for newly generated native LW runs: native.jl
now defaults --continuous-descent to on and records it in the generated spec.
Use --continuous-descent off for comparison. Frozen --spec inputs retain their
explicit setting; older specs lacking the key retain legacy off for replay.
This adoption covers observed-target ordinary walking, not hidden-target search,
repositioning, running, climbing or all model fields. Performance, long-term
reliability and richer obstacle scenes remain separate validation questions.
The midangle comparison at food(5,16) completed one day per condition with all
three returning and one pickup each; audit10 passed. C's last15 seconds before
pickup used headings -45/45 in the discrete condition versus9.454 degrees in
continuous descent. This is finite evidence for removing quantization, not a
claim of general efficiency improvement.


## Stable LW entry integration, 2026-10-14

`integrations/lightweight_julia/run.jl` delegates to native.jl and therefore
adopts the new generated-input default without another simulation loop.
`descent_lw_checks.jl` runs that entry with the composed riparian configuration:
patch resistance, wear/perception, mixed hazards, running/climbing/drop,
shared storage, general Sleep and experience-based social response.
Seed20261005, one day, 51,840 operations; call48.274sec including compilation.
Local/adoption checks9 PASS; safety20 + integrated4 + entry6 =30 PASS.
Output: outputs/descent-lw-integration-1 (spec, manifest, result, summary).

Pickups A/B/C=4/3/1; shared stock5, held1, consumed6, ground112;
initial124=112+5+1+6. Reserve88.919/88.874/89.082.
Sleep A/C pending, B completed; B ends away from home. This is an integration
and conservation check, not universal return/Sleep success or an off/on causal
comparison. Rich-world navigation remains an observation target.

The prior benign midangle10-day run (outputs/descent-ten-day-1) completed in
212.258sec with pickups28 each, shared60, consumed30, all30 Sleeps completed,
all agents near home at every day end, and59 daily audit assertions passing.
These two environments must not be conflated.

## Parent-scoped search review

Relocation now asks `target_observed`, rather than treating a performed walk as
search success. Its accepted body result remains unchanged. The home goal is
still resolved only at home. Repeated performed relocations without a target
accumulate bounded review pressure; at the parent threshold this raises the
existing survey candidate's priority (maximum +4). A performed survey clears
this request to look, but an unsuccessful survey does not clear parent or method
H. Changed purpose clears the local review pressure. Safety and other higher
priority actions remain in control. Relocation cannot use inertial continuation
to substitute movement_progress for the search question.

This is a finite child-choice adaptation, not a full new hierarchical model
ontology. It checks direct target acquisition; recognising a useful indirect
landmark as search progress is still a separate extension. Tests in
search_review_checks.jl:8 PASS, including unresolved parent H and both methods
being selected. No return guarantee is imposed.
