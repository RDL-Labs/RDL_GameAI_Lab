# LW Julia completion audit — open

Reference: Python integrations/lightweight/integrated_social_campaign.py and
its timed_harvest.run implementation; native source bf938f5. Full trace parity
is not the contract. This is a completion checklist, not a completion declaration.

| Required outcome | Evidence / remaining verification |
|---|---|
| Native generation/run/save | native.jl -> run_integrated -> lw_day; native_report and frozen-spec replay |
| Major function coverage | Integration_Status matrix, source-specific reports; functional adaptations below |
| Latest 30 days, multiple seeds | NOT YET: old long_run_report predates current features; three-day matrix38373033395 passed both seeds and independent saved audit; latest30-day run pending |
| Food/cargo conservation | per-operation invariant plus daily/terminal audit; latest all-feature campaign pending |
| Learning/Sleep/use/invalidation | harvest renewal B1g and Sleep body-method reports; current campaign state coverage pending |
| Dormancy/reactivation | live source paths in sleep_maintenance and experience_bundles; need extract actual campaign counters, do not equate enabled with observed |
| Parent goal persistence | return-purpose/drop tests and bound in campaign; latest combined behavior pending |
| Time/memory | native @timed allocations/GC and process peak RSS; final campaign measurement pending |
| Differences | matrix and source reports; final backend-switch decision remains NOT READY |

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
migration prerequisite. Production backend switch remains pending this audit.
