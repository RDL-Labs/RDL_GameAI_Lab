# Safety Failure / Incapacitation Contract

**Status:** Phase 5A finite failure slice

## Chain

```text
bounded danger exposure
-> committed Safety trajectory
-> three fixture-controlled flee resolutions make no progress
-> Godot BodyState records severe injury
-> Godot BodyState records incapacitated = true
-> subsequent bounded self-body snapshot
-> Runtime constrains world-changing action to idle
```

Godot owns danger contact, failed world resolution, exposure count, injury, and
incapacitation. Runtime does not infer injury from danger or failed movement; it
only validates and obeys the bounded self-body snapshot.

## Finite fixture

The first experiment uses exactly three failed flee resolutions. This is a test
threshold, not biology, health, damage points, personality, affect, or canonical
semantics. Normal Safety fixtures remain unchanged and still permit successful
escape.

The injury vocabulary is finite:

```text
none / light / medium / severe
```

Only `severe` may accompany `incapacitated = true` in this slice. An
incapacitated body cannot execute approach, pickup, eat, deposit, rest, sleep,
or flee through the Runtime response.

## Exclusions

Discovery by another NPC, rescue, carrying, return home, staged recovery,
missing/search, failsafe warp, death, canonical M_B admission, H, and T1 remain
deferred. No rescue or system warp result is admitted as successful experience.
