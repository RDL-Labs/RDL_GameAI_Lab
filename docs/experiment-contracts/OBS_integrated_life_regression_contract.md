# OBS-6 Integrated Life Regression Contract

## Status

Operational finite integration regression for RW2 life plus isolated sensing.

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

Local vision follows the selected profile radius. Distant vision uses a finite
per-agent fixture target and the observer's current position/yaw. Audition uses
the receiver's event-time pose and profile gain. Local samples occur every
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

