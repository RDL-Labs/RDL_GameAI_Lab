# Actual-use selection trails

Source `ebf94c4`, reference runtime/selection_trail.py.
[Actions 38362274089](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38362274089):45 assertions PASS.

Edges bind actor food-sufficiency parent,current context,phase,method and native
action/direction. Max512 edges. Real accepted use adds min(1,uses*.02) to later
candidate priority. A hungry episode persists without an elapsed-time failure;
observed reserve>80 distributes 1+min(8,max H) equally across distinct used edges,
with each accumulated success_credit capped8. Its priority term caps1. Uses are
not causal success; whole-episode credit is not an independent proof for each edge.

Native action descriptor uses combined walk/direction and method-level scan
(default scan orientation is chosen later by its existing adapter). It does not
claim Python command-byte parity. Protected phases and committed movement are
outside this projection. Recording occurs after actual execution; parent success
is checked at the next observation. Same accepted operation is not counted twice.

Four continuous days,seed20261005,bundles and parent credit enabled in both arms.
Saved summaries independently checked for food conservation:

* off:100+37=ground78+stock44+carried0+consumed15; Sleep 12/12
* on:100+29=ground84+stock30+carried0+consumed15; Sleep 12/12
* npc_b:edges=71, uses=7593, changes=105, completed episodes=3
* npc_a:edges=74, uses=967, changes=156, completed episodes=1
* npc_c:edges=55, uses=713, changes=156, completed episodes=0

No stock-efficiency inference: replenishment totals differ. Compile/order and
behavior differ between arms; no performance speedup claim. Fourteen local tests
cover actual use,replay,failed admission,parent waiting/completion,binding and
selection change. Full sensing/inherited World and latest30-day acceptance remain
open; no canonical T1 claim.
