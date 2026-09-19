# Rescue Goal and Trajectory Contract

**Status:** Phase 5C finite approach slice  
**Runtime:** `python -m runtime.bridge --rescue-trajectory`

## Operational path

```text
bounded visible agent condition = incapacitated
-> Rescue Goal
-> one target selected and committed
-> approach(target_id)
-> subsequent bounded observation
-> within_reach
-> READY_TO_RESCUE
```

The policy selects the lexically first incapacitated candidate only when no
Rescue trajectory exists. Later candidate order or a newly visible candidate
does not replace the committed target. If that target disappears from bounded
observation, the trajectory is `RELEASED` rather than redirected implicitly.

`READY_TO_RESCUE` emits `idle`. It means only that the rescuer reached the
incapacitated agent. It does not mean pickup, carrying, treatment, delivery,
recovery, success, or Experience admission.

## Authority boundary

```text
World owns position and incapacitation
Runtime owns finite Rescue Goal / commitment / approach decision
World-changing rescue resolution remains deferred
```

The old Safety trajectory of the incapacitated agent is not resumed or cleared
by Phase 5C. Recovery must use a fresh bounded observation and current-relation
re-evaluation in a later contract.

## Acceptance

1. Discovery forms one Rescue Goal for a bounded incapacitated agent.
2. The target remains fixed while still observed.
3. Godot resolves approach toward the actual agent position.
4. Arrival produces `READY_TO_RESCUE` and `idle`, not invented rescue success.
5. Target disappearance produces `RELEASED`.
6. Replay is frozen by agent and observation identity.
7. Existing canonical sidecar, H, T1, Food, Rest, and Safety authority remain unchanged.
