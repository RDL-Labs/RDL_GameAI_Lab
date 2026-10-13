# LW Julia completion audit — completed for standalone major-function migration

Reference: Python integrations/lightweight/integrated_social_campaign.py and
its timed_harvest.run implementation; native source bf938f5. Full trace parity
is not the contract. Final decision: [standalone backend ready](RDL_Julia_LW_Backend_Decision.md).
See the decision for evidence, reproduction commands and explicit differences.

| Required outcome | Evidence / remaining verification |
|---|---|
| Native generation/run/save | native.jl -> run_integrated -> lw_day; native_report and frozen-spec replay |
| Major function coverage | Integration_Status matrix, source-specific reports; functional adaptations below |
| Latest 30 days, multiple seeds | PASS: campaigns38376126204 (reference) and38423218244 (typed geometry), seeds20261004/05, 30 days plus frozen replay; independent saved audits passed |
| Food/cargo conservation | per-operation invariant plus daily/terminal saved audit passed in both30-day campaigns |
| Learning/Sleep/use/invalidation | harvest renewal B1g and Sleep body-method reports;30-day Sleep model applications and selection changes observed in both seeds |
| Dormancy/reactivation | OBSERVED: seed04 Sleep models woken=3 (B); experience bundles woken=87 seed04 /71 seed05. These are counters, not independent causal-effect counts |
| Parent goal persistence | return-purpose/drop tests plus completed<=entries bound passed in latest campaign; this bound alone is not proof of every interruption behavior |
| Time/memory | measured: optimized initial calls1519.862s /1084.617s; allocated361.993GB /348.016GB; peakRSS1.383GB /1.546GB (seed04/05) |
| Differences | matrix and source reports; READY for standalone LW experiments; see Backend_Decision |

## Configuration contracts

The Python production wrapper's OPTIONS is not every timed_harvest option.
The later optional personal-food, body field, experience-bundle and ground-history
paths must be mapped separately. Separate established fixtures are evidence for
mutually exclusive modes; enabling every flag simultaneously is not fidelity.

Python rejects trail_enabled with bundle_credit_enabled. Julia now rejects the
same double-credit configuration. Cancelled38372683370 used that invalid mix and
is not acceptance evidence. Corrected38373033395 uses trails, no bundle credit.
Bundle formation/use/dormancy remain enabled; bundle-credit life/local evidence
remains in its own report.

Julia body/hunger is directly supported for both store modes; Python's hunger
adapter depends on personal_food. This is a declared adapter generalization,
not a claim that Python permits the same configuration. Shared-resource retrieval
is verified separately; newest campaign tests the composition explicitly.

Julia actions are combined heading/step with one-second body execution. Python
has separate turn/move commands and configurable observation cadence. Methods,
current sensed feasibility and actual results are compared functionally.

Current native local home sensing reports relative distance; Python dock uses
angle/reach. Native finite color/angle routes and supplied harvest schemas do not
constitute a global map, general relation invention, or canonical T1 adoption.

Luanti/HTTP integration is outside standalone LW migration. Existing Python
experimental rest-reactivation is not called by production LW and is not a new
migration prerequisite. The standalone Julia entry is ready under the declared adapters; the Python entry is retained.

## 2026-10-14: resumed completion review

The optimized cloud campaign38423218244 ran commit966949d on an experimental
branch, not main. Both frozen specs and result.json files were byte-identical
to reference campaign38376126204. Each campaign case executed1,555,200 operations.
Independent audits are saved under outputs/julia_migration/cloud-38423218244.
Timing is a cross-job comparison, not a controlled repeated benchmark: initial
calls decreased from8284.235s to1519.862s (seed04), and9274.310s to1084.617s
(seed05). Workflow wall time also includes frozen replay and setup.

This closes the pending long-run evidence, not the entire migration goal.
The feature correspondence matrix, outstanding local changes and backend-switch
packaging still need review. Unrelated goal-threshold edits were excluded from
these experiments. No canonical T1 claim or complete Python trace parity is made.


Final2026-10-14 audit: runtime72ff1d5 adds validated threshold/handedness adapters
and stable entry. Parent-purpose71-assertion regression passed on this source.
All requested deliverables are linked in Backend_Decision and Integration_Status.
Earlier pending notes are historical; GitHub main publication is separate from
this local code/behavior acceptance. No generic-kernel restructuring was performed.
