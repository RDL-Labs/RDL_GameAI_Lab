# Shared camp storage and periodic resource floor

Source3bc7555; reference social_life.py and resource_regrowth.py.
--stores personal (default) retains the existing native private stores; shared
uses one World-owned stock. Only at-home decisions can retrieve it, and execution
checks local reach again. Deposit transfers carried food into it, retrieve moves
one unit out; sequential execution resolves simultaneous demand without creating
food. Shared and initial private stores cannot be combined implicitly.

The food ledger includes shared stock exactly once. Agent private stocks remain
zero in shared mode. Shared inventory and configuration survive environmental
cohort transfer; previous agent-held food is not transferred with it. Cargo
source handling remains the existing accepted-deposit/unknown-stock-source model.
No automatic ownership relation or negotiation feature is added.

--regrowth-days N controls the global World-day period. --regrowth-capacity K
sets the minimum replenished resource stock, never subtracting excess stock.
The default capacity0 preserves each original resource's native cap; positive
capacity12 matches the Python reference setting. Original resource sites only
are replenished; dropped objects are not. World offset determines the phase
across cohort boundaries and incompatible settings are rejected.

## Acceptance

Source 2c82bac; Actions [38370227210](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38370227210) succeeded.
58 assertions: baseline safety/current-observation20, resource floor3,
five life invariant sets20, mode/period6, sharing6, replay1,
positive remaining stock1 and inherited stock1.

| Run | Initial | Added | Ground | Shared | Private + carried | Consumed |
|---|---:|---:|---:|---:|---:|---:|
| personal,4days |100|59|48|0|105|6|
| shared,4days |100|59|48|105|0|6|
| sharing,1day |18|0|0|12|0|6|
| inherited,new cohort,1day |12|0|0|6|0|6|

The sharing fixture starts A with18 carried units and B/C hungry at camp.
Successful retrieval by another actor is required. The remaining12 shared units
are transferred with an empty resource list; fresh agents consume6 of them.
This transfers environmental stock, not prior agents' bodies or learned state.
Frozen sharing replay is byte-identical. Downloaded results independently pass
final food conservation and replay checks. Private/shared outcomes here do not
establish general social or efficiency benefits.

Two failures were repaired before acceptance: the per-operation conservation
assertion originally omitted shared stock (fixed1c9e2cc), and restoring an empty
JSON resource array inferred Union{} rather than Int (fixed2c82bac). The latter
is now covered by nonempty shared-stock transfer through an empty-resource World.
Failed runs38369218616/38369475050 are not acceptance evidence.

Latest-feature30-day integration and the full repository suite were not run by
this workflow. Shared storage remains opt-in; personal storage is unchanged.
