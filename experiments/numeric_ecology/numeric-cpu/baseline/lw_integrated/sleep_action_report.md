# Julia Sleep action models: adoption and bounded use

Code `752cbeb`; [run38344148767](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38344148767)
passed41 assertions (safety16, model14, integration8, native use3).
No repository-wide or full LW migration claim.

## Finite port

`--general-sleep apply` adds automatic unvalidated local action-outcome records
and a bounded priority contribution, adapted from runtime/sleep_auto_model.py.
Completed Sleep admits its frozen review records with owner/time validation,
source-id deduplication/conflict rejection and a192-record capacity. It does not
require the review to have two different strata: one empirical record can enter,
as in the Python automatic model path. It is not validated knowledge or canonical
T1. Record staging prevents partially published admission on validation failure.

Current observations now explicitly report food coverage as partial if more than
five visible features were truncated; complete refers only to the sensor's finite
view, not World-wide food. Context requires complete food and hazard views and
contains their presence booleans plus five local walk rows (reference, load,
feasibility status, resistance). Hidden coordinates and resource quantities are
not included. This is a Julia-local capability context, not exact Python body-
context parity; full body state/strain history and dynamic resolution remain gaps.

Records retain observed pre-action context and direction. Only walk/scan candidates
are affected, matching both context and direction, with performed/blocked outcomes.
Priority contribution is0.75*(2*execution_rate-1), using distinct source records.
Rest and other operations remain stored but do not create new movement candidates.
No unknown/blocked direction is restored; existing candidate generation and higher
priorities remain authoritative. No same-timestamp application at Sleep completion.
Execution outcome does not reset the parent-purpose H or certify goal success.

Harvest projection is evaluated before this additional contribution; its diagnostic
selection difference now explicitly uses the pre-Sleep choice so that Sleep effects
are not attributed to harvest. Sleep difference compares the same current loop
state/candidates with versus without this last contribution. These counters are
local counterfactuals, not separate complete trajectories.

## Three-day result

Native seed20261005, renewable food, other optional adapters off, review/apply:
155520 operations each, all nine Sleep cycles complete. Stored model sources:
A3,B5,C3. B has5054 application decisions and zero changed selections. A/C have
zero applications; their retained sources are rest. No criteria were relaxed to
force a visible effect. Local synthetic blocked-walk evidence changes a selection
from walk to scan; that effect is not observed in this World run.

Both stocks A65/B6/C53, carried B5. Food:
100+107=72 ground+124 stored+5 carried+6 consumed.
Downloaded results match exactly except the `sleep_action_models` diagnostic.
Ledgers were independently recomputed from summaries. This demonstrates actual
post-Sleep model use, not better behavior or a live action divergence. Compilation
states differ; timings are not a performance comparison.

Still unported: full automatic action vocabulary, rich body/social contexts,
bundle dormancy/reactivation, general candidate formation and canonical adoption.
The bounded recent history often contains only rest; no broader experience retention
or successful-experience injection is introduced in this increment.

## Body-method integration (2026-10-13)

Source77f8e35 expands projection to existing run/climb/rest candidates in addition
to walk/scan. It does not synthesize actions or bypass physical eligibility.
Fixed pickup/deposit/social/night choices remain upstream authorities rather than
being introduced as competing candidates. Python uses its native action/amount
vocabulary; Julia uses native action/direction, with one-second execution units.
This is functional adaptation, not command-level parity or canonical T1.

Context additionally records observed run feasibility/load/resistance and, when
climbing is enabled, five climb heights/capacities, statuses, load/resistance,
path and landing clearance. Prior context remains a detached value snapshot.
Changed capability therefore prevents reuse of a physically different cell;
unknown food/hazard coverage still prevents any projection. There is no global
terrain, hidden resource count or target World identity in this context.

Cloud38370828676 passed45 local checks but rejected the life fixture because
body-field lacked its required food-body flag. Test configuration3abcdd9 supplies
that prerequisite. Replacement [run38371144577](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38371144577) succeeded57 assertions:45 local,8 life invariants,3 model-use and1 frozen replay.

Both modes ran3 days,3 actors,155520 operations. Review-only:
100+9=ground90+private/carried8+consumed11. Apply:
100+9=ground93+private/carried5+consumed11. Saved results independently satisfy
conservation; apply/replay result bytes match, including terminal states.

A/B/C retained15/17/11 records; applications8584/16/8581 and same-state selection
changes8581/0/0. This is influence, not efficiency improvement or independent
causal trials. The loop admitted rest/walk/scan plus fixed-operation records;
run/climb sources did not occur in this life fixture. Run/climb projection is
therefore verified locally, not claimed as witnessed learned use in this run.
Exact context matching remains narrow, and automatic execution-success bias can
favor unhelpful behavior. No coefficient tuning was performed to force improvement.
Latest-feature30-day and repository-wide tests remain separate pending gates.
