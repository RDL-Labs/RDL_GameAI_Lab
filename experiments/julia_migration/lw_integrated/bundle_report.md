# Native LW own-experience conjunction lifecycle

Source `dd23ff5`. References: runtime/experience_bundle.py and bundle_sleep.py.
[Actions 38361000866](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38361000866)
passed46 assertions:20 shared,15 lifecycle,8 invariants,3 living bounds.

Formation follows a new unresolved hunger comparison, from at most8 own received
operations no older than10 seconds; each operation belongs to one bundle only.
Material is unvalidated. Active capacity32,total256. Context combines food band,
food/hazard coverage and presence,reserve<=80,strain>=.8. No world truth labels.
Current matching sources subtract at most.75 from same-action candidate priority;
frequency is not independent causal evidence. Existing authority gates remain.

Only completed Sleep reviews idle use: two idle Sleeps with opportunities,three
without. Dormant bundles remain stored and may wake under matching current context
if an active slot exists. Native IDs are deterministic per-actor sequence IDs;
Python payload hashes and mutable-copy semantics are not required. State is owned
per run, snapshots independent. Candidate scoring uses existing native BasicLoop.
Body-field attribution is measured before bundle projection to avoid miscredit.

Four days,seed20261005,three actors,renewable food,food/body,general Sleep apply,
stratified retention.207360 operations each. Independently checked food balances:

* off:100+32=ground81+stock36+carried0+consumed15;Sleep12/12.
* on:100+37=ground78+stock44+carried0+consumed15;Sleep12/12.

A formed32 bundles,303 matched decisions,6 executed changed selections.
C formed32 bundles,771 matched decisions,0 changes.B formed none.
All64 bundles became dormant through completed Sleep. Live wake count=0;
matching-context wake is tested locally, not yet observed in this living run.
Stock differences with different replenishment are not an efficiency finding.
First/off call41.48s,on28.61s; compilation/order and behavior differ,no speed ratio.

Parent-H success-credit and selection trails remain unported. This is not a
substitute for those functions or canonical T1 reconstruction. Full LW acceptance
and latest-feature multi-seed30-day rerun remain outstanding.
