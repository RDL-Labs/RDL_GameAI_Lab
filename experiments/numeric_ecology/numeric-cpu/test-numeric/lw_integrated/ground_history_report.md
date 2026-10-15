# Environmental ground history transfer

Source `a5a02ba`, [Actions 38362996096](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38362996096).
42 assertions PASS:20 shared,7 restore,14 living/replay invariants,1 exact replay.

Frozen scene may include ground_history from a previous result's ground_wear.
The existing native entry and living loop load it only with ground wear enabled.
Ground time continues from snapshot time while new agents begin their local clock.
Snapshot wear is already decayed; restore reconstructs its anchor so earlier
recovery is not applied twice. Old actor names are qualified inherited/ before
new cohort wear is added. Agent learning/body/positions are not restored.

One day builds a worn surface; a fresh cohort uses that surface for one day.
Same inherited input replay independently verified byte-identical result.json.

* first: cells=407, cumulative wear operations=21272, ground time=17280000000
* next: cells=992, cumulative wear operations=42149, ground time=34560000000

This is a ground-history component, not a complete cohort_world checkpoint:
resource stock,regrowth state,dynamic hazards and shared stores are NOT transferred.
Resource initialization in the second experiment is explicit; never describe its
food as conserved across both cohorts. Full environmental transfer remains work.
No claim of beneficial route understanding or aggregate efficiency.
