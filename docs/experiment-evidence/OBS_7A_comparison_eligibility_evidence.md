# OBS-7A Comparison Eligibility Evidence

Observed 2026-09-26, starting from main `f06c1084`.
[Contract](../experiment-contracts/OBS_7A_comparison_eligibility_contract.md).

## Python diagnostics and replay

```powershell
python -m unittest discover -s tests -p test_sensory_comparison.py -v
python -m unittest discover -s tests
```

- OBS-7A: 14 tests passed.
- Full Python suite: 342 tests run = 296 passed + 46 intentionally skipped.

Synthetic positive frames pass through the real SensoryObservationStore before
diagnosis. Two overlapping audition detections with the same scoped acquisition
pose and permitted conditions return eligible with no reasons. This proves the
finite eligibility rule, not source identity, similarity or a cross-modal match.

Tests include half-open timing boundaries, empty intervals, point equality,
detection-level pose, coverage/status/output limits, unknown direction,
clock/model/profile differences, multiple reasons, missing element selection,
invalid/context-crossing references, atomic refusal, finite budgets, detached
outputs and no input mutation. Opposite azimuths around -180/+180 remain eligible
when the prerequisites hold: the diagnostic performs no numerical direction
match and makes no wraparound overlap or identity claim.

Retransmission uses new observation IDs and later delivery times against the
actual store. It returns new_frames=0; diagnosis is invariant to duplicate or
reversed pair requests and snapshot frame order. No support count is produced.
Fixed packet replay with diagnosis called or omitted yields identical action
responses, InteractionHistory snapshots, canonical snapshots and sensory store.
This is Python fixed-packet evidence, not complete live action-sequence equality.

## Newly captured real Luanti source

The existing sensory-enabled RW2/OBS-6E harness was run with an ephemeral copy
that only exported its GET sensory snapshot before shutdown. Sensor generation,
Runtime admission and action code were unchanged. The copy was removed afterward.
Output:

```text
OBS6 SENSORY: agents=2 channels=3 rejection_recovered=1 transport_retry=1 response_loss_retry=1 duplicate_new_frames=0 ack_only_removal=true life_compatible=true
OBS7A SOURCE LIFE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:2,B:1
```

The source snapshot had 36 frames. The checked-in
[replay fixture](../../tests/fixtures/obs7a_luanti_replay.json) records context,
assignments and two unmodified admitted frames: first stored npc_a distant frame
with a feature, and first stored npc_a audition frame with a detection.
This is a projection of real admitted data, not regenerated or pose-normalized
synthetic input. Capture origin, baseline, selection and source count are stored
beside it. The complete local export is
`integrations/luanti/output/obs7a-snapshot.json` (generated, not tracked).

Replay of those selected elements returns:

```json
{"status":"not_comparable","reasons":["no_temporal_overlap","pose_mapping_unavailable"]}
```

The result preserves the distinct capture times and eye/ear pose references.
No attempt was made to change them to create a real-World positive example.
Real Luanti was used to acquire and admit the source; OBS-7A diagnosis was then
performed by Python replay, not inside Luanti or the HTTP action callback.

## Stop boundary

OBS-7A is complete as a pure local diagnostic and replay slice. No endpoint or
UI was added, and no browser test was run. This round did not rerun standalone
OBS-3/OBS-4C or sensory-disabled RW2. Their earlier evidence is not counted as a
new execution here. OBS-7B candidate generation, OBS-8 gaze actions, coordinate
transforms, canonical interpretation and long-term retention remain deferred.
