# Rescue Safe-Place Delivery Contract

**Status:** Phase 5D finite world-interaction slice  
**Runtime:** `python -m runtime.bridge --rescue-trajectory`

## Operational path

```text
READY_TO_RESCUE
-> rescue(target agent)
-> Godot records carried_agent_id
-> bounded safe place selected once
-> carried target follows rescuer movement
-> deliver(safe place)
-> Godot records last_rescue_delivery
-> subsequent bounded observation
-> COMPLETE
```

Godot owns attachment, carried movement, delivery position, and the delivery
record. Runtime owns the finite Goal, fixed injured-agent target, fixed safe
place target, and structured actions. `COMPLETE` is admitted only after a later
body snapshot reports the matching agent and place; issuing `deliver` alone is
not success evidence.

## Safety and recovery boundary

The delivered target remains `injury_level = severe` and
`incapacitated = true`. Delivery is not treatment, recovery, revival, death
handling, or Experience success admission. The target's old Safety trajectory
is neither resumed nor cleared by this slice.

If no safe place is bounded and visible after attachment, or the committed
safe place disappears, the trajectory remains `DELIVERY_BLOCKED` with `idle`.
The carried agent is not silently dropped or redirected.

## Acceptance

1. Rescue attachment requires the incapacitated target to be within reach.
2. The carried target follows actual Godot movement.
3. One bounded safe place is selected and remains fixed.
4. Delivery occurs only within reach of that safe place.
5. Runtime completes only from matching subsequent World provenance.
6. Delivery does not change injury or incapacitation.
7. Existing Food, Rest, Safety, canonical sidecar, H, and T1 behavior remain unchanged.
