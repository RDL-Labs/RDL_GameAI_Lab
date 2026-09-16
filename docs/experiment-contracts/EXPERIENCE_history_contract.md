# Experience History: Read-Only First Slice

This GameAI-local layer owns finite interaction history. It is not Core M_B,
H, affect, trust, or an action policy. It does not change canonical comparisons.

## Path

```text
accepted bounded observation -> Runtime approach decision
-> Godot world resolution -> distinct subsequent observation ID
-> bounded result report -> admitted interaction record
-> per-agent / target / perception-context history snapshot
```

`POST /v1/observe` admits up to 128 approach decisions per process into the
history correlation table. Issuing a decision alone does not create experience.
Idle decisions are outside this slice. Action responses are unchanged.

Godot sends `POST /v1/interaction-result` after a valid approach resolution:

```json
{
  "agent_id": "npc_b",
  "source_observation_id": "<accepted approach observation>",
  "subsequent_observation_id": "<distinct observation after resolution>",
  "target_id": "food_01",
  "tick": 1,
  "outcome": "approach_progress"
}
```

The report must match an admitted agent/source/target, use a distinct subsequent
observation ID, and have a tick no earlier than the decision. The two outcomes
are `approach_progress` (position changed during approach) and
`approach_no_progress` (position unchanged, including already being at target).
No-progress does not imply failure, dislike, or negative emotion. The report
contains no complete world state or absolute world positions.

This is a workbench-reported result: Python verifies correlation and shape,
not the truth of the physical outcome or the contents of the later observation.
This endpoint does not feed the reported outcome into canonical RIB_B/E/H.
Missing-target resolutions and idle actions currently create no history report.

## State and Ownership

`runtime/experience.py` owns accepted decisions and completed results. Each
source decision has at most one result. Exact replay is idempotent; conflicting
results or observation-ID reuse with a different decision/context are rejected.
Source and later observation IDs, decision/result ticks, target, context, and
reported-outcome provenance remain attached to each record.

`GET /v1/experience-snapshot` exposes records and relation groups. Groups keep
progress and no-progress record IDs in separate lists; there is no net affinity
score. Agent and perception context are separated. Returned snapshots cannot
mutate the stored history. No unobserved target is introduced by the report.

Retention is process lifetime, at most 128 admitted source decisions including
pending results. There is no eviction, decay, or automatic forgetting. Capacity
rejection is counted; existing records remain available and new action decisions
still run. Unadmitted result reports return 422. Restart clears all history.
Use a fresh runtime after a Godot reset because observation IDs/ticks are reused.

Godot serializes result reporting before the next Runtime request. The Decision
Record shows `History: accepted` or a report failure. Failed/cancelled reports
are not retried automatically; pending counts remain observable. Reset/mode
switch cancels local outstanding requests, but does not roll back server records.
History is inspected through the snapshot API; a full history UI is deferred.

## Acceptance and Next Boundary

The Python tests cover correlation rejection, pending versus completed state,
idempotence/conflicts, agent/context isolation, snapshot independence, retention,
and HTTP report/snapshot behavior without action or canonical state changes.
The Godot headless interaction check covers progress, no-progress at the target,
and exclusion of world positions from the bounded result.

`tests/test_experience_godot.py` additionally runs the actual Workbench against
a test-owned localhost bridge when `GODOT_BIN` is set. It verifies 12 accepted
results, both outcome categories, distinct observation instances, zero pending
results, and no automatic H contribution. It requires port 8765 to be free.

This slice establishes read-only Experience storage, not the complete Next 2
behavioral acceptance. Next, define a reviewed influence path and compare the
same current observation/body/sensitivity with different finite histories.
Social support/avoidance, positive/negative social histories, forgetting,
restart persistence, and canonical model reconstruction remain unimplemented.
