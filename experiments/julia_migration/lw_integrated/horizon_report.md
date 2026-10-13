# Cross-day exploration pressure in native LW

Source `29135ca`, Python reference `runtime/exploration_horizon.py`.
Eight exploration move/turn/wait/blocked results without acquisition add one
local H, capped32. No date reset. Actual acquisition clears H/count. H>=2 admits
currently observed mid/far patches, <=45 degree width, aligned to a physically
feasible direction within22.5 degrees. Priority=2+min(4,H/2)*(far ? 1 : .35).
No hidden coordinates, new traversability or guaranteed resource destination.

Native port uses combined walk/turn operations; candidates ask actual movement
progress. Result admission happens on execution, available at the next decision.
This differs in scheduling from Python's subsequent-observation admission, without
adding extra operation authority. Per-run state is actor-local. Fan source and
feature index preserve subjective provenance instead of inventing World IDs.
Current goal, return, safety and movement continuation retain their earlier gates.

[Actions 38360261853](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38360261853):
41 assertions PASS, including11 horizon boundary checks and3-day common-loop
comparison for seed20261005. Food conservation independently checked from saved
summaries. Each run155520 operations.

* off: added=96, ground=42, stock A/B/C=[45, 68, 35], carried=0, consumed=6, Sleep=9/9
* on: added=77, ground=60, stock A/B/C=[35, 29, 47], carried=0, consumed=6, Sleep=9/9; horizon selections={'npc_b': 11135, 'npc_a': 12596, 'npc_c': 12802}

Different replenishment totals prohibit equal-supply efficiency inference. One
seed does not establish improved exploration. Default is off; frozen old specs
remain compatible. Full LW migration and latest-feature30-day acceptance remain
open. This local H is not canonical T1 admission.
