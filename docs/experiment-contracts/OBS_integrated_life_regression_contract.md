# OBS-6 Integrated Life Regression Contract

## Status

Operational finite integration regression for RW2 life plus isolated sensing,
using the same distant-vision and audition-window kernels as the standalone
OBS-3 and OBS-4C fixtures.

## Vertical

```text
same Luanti World / same Runtime
├─ npc_a: Food -> Base -> deposit -> causal result
├─ npc_b: Food -> Base -> deposit -> causal result
└─ each legacy observation delivery
   ├─ vision_local instant frame
   ├─ periodic vision_distant instant frame
   └─ previous-window audition frame
      -> isolated sensory store
      -> OBS-5 read-only p5 projection
```

The extension is attached immediately before `/v1/observe`. Runtime removes it
before the existing Food policy, Experience, and canonical consumers run.
Approach resolution records a finite action sound for the other agent; it does
not create a sound meaning, danger label, or action response.

Audition windows close on every World tick independently of HTTP exchange.
Closed frames wait in an agent-owned delivery queue and retain their original
capture window and sampled tick when a delivery is skipped. The fixture queue
is bounded to 64 frames per agent; it is transport staging, not memory.
Local and distant frames enter the same queue. A delivery selects at most four
oldest frames, records them as in-flight, and removes them only after an
explicit accepted `sensory_receipt`. HTTP failure or isolated sensory rejection
releases in-flight state while retaining the queued frames for a later
observation; the legacy action is not replayed merely to retry sensory data.

Local vision follows the selected profile radius. Distant vision reads the
finite target node from the World and applies the shared range, field-of-view,
voxel-coverage, occlusion, and output-limit rules. Audition records the
receiver's event-time pose and uses the shared half-open window, split,
idempotent-close, buffer-limit, detection-limit, and voxel-transmission rules.
World corridors and fixture targets are initialized once; later wall placement
or target removal is not silently reset. An unclosed initial
audition window is not projected as a future capture. Local samples occur every
World tick, distant samples every four ticks, and audition closes one interval
per delivery. Their times remain independent.

This integration fixture is process-local and bounded by the short RW2 run and
the Runtime's existing 64-frame-per-agent/channel store. General unclosed-window
retention, long-running history compaction, sensory meaning, fusion, and action
influence remain outside OBS-6.

## Acceptance

1. A/B independently complete pickup, return, deposit, and accepted result.
2. Existing visible-agent counts remain A=2 and B=1.
3. Both agents retain local, distant, and audition channels with no cross-agent
   frame identity.
4. Each agent has at least one distant feature and one heard action sound.
5. Local and periodic distant schedules retain at least one distinct capture
   time; the viewer must not imply synchronization.
6. Sensor admission rejection count remains zero and capture time never exceeds
   its sampled World tick boundary.
7. The same RW2 test passes with sensory integration disabled.
8. No Experience, canonical, Goal, Trajectory, or action authority is granted
   to any SensorFrame.
9. Sensory-enabled and sensory-disabled RW2 both complete the same finite life
   acceptance. Exact action-sequence equality is not claimed by this fixture.
10. A skipped delivery retains the closed audition window with its original
    time, while a wall, target removal, and wall transmission remain observable
    after fixture initialization.
11. A delivery never exceeds four frames. Four skipped ticks, a rejected
    extension, and a pre-send transport failure retain and later admit the
    affected frames without duplicate sensory storage.

