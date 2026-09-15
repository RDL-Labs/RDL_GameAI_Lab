# P2 Interaction Loop Contract

P2 establishes the smallest action-to-subsequent-observation loop.

## Current Status

P2 is **accepted and retained** under the Core v2.3 roadmap.

It still does not implement canonical `RIB_B`, `M_B`, `F`, `F'`, `E`, `H`, or Human Attention.

## Goal

Show that a runtime action can become an actual response in the Godot world, change interaction conditions, and cause a subsequent bounded observation to be generated from those changed conditions.

```text
interaction conditions
→ bounded observation packet
→ runtime action
→ world resolution / actual response
→ changed interaction conditions
→ subsequent bounded observation packet
```

Core v2.3 migration adds acquisition later:

```text
bounded observation packet
↓ Purpose / finite B acquisition
RIB_B
```

P2 itself stops before that semantic step.

## Boundary

In scope:

- existing mock world reference state
- selected agent bounded observation
- localhost runtime action response
- one minimal world-resolution path for `approach(target)`
- timeline / inspector evidence showing source and subsequent observation instances

Out of scope for P2 itself:

- canonical `RIB_B` acquisition
- `M_B`, `F`, `F'`, `E`, or `H`
- static structural conflict to `E/H`
- Human Attention workflow or Human Attention load
- relation history
- learning
- T1 Reconstruction
- LLM dialogue

## Required Separation

The runtime chooses an action from the bounded observation packet only.

The Godot workbench owns world resolution:

```text
runtime action
→ Godot world-resolution path
→ world reference state change
→ new bounded observation packet
```

The source observation and subsequent observation must have distinct observation instance IDs even when they occur in the same tick:

```text
same tick != same observation
```

Invalid shortcut:

```text
runtime action
→ fabricated next observation fixture
```

## Minimal Action

Only one world-changing action is required for P2:

```text
approach(target_id)
```

For the current mock world, `approach(food_01)` moves the selected agent toward the food object through the provider's resolution path. The movement offset is preserved across ticks so later observations are generated from changed conditions, not from an independent fixture.

## Acceptance Evidence

P2 is accepted when evidence shows:

- a runtime action is returned from a bounded observation;
- the action is applied through a world-resolution function;
- the selected agent's world position changes;
- the subsequent bounded observation is generated after that world change;
- subsequent observation id differs from source observation id;
- the Timeline records the resolution path;
- the implementation does not fabricate `RIB_B`, `F/F'`, `E`, `H`, Human Attention, or T1 Reconstruction.

## Stop Rule

Stop P2 when the current finite experiment Boundary is operationally sufficient to establish:

```text
action
→ changed interaction conditions
→ subsequent bounded observation
```

The next semantic step belongs to P3 acquisition, not P2.
