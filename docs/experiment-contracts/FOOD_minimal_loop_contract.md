# Minimal Food Loop Contract

## Boundary

```text
FoodNeed → bounded food perception → approach → pickup → eat
→ food removed from world and held state → FoodNeed decreases
```

Godot owns world objects, pickup reach, per-agent FoodNeed, held food IDs and
world resolution. Python receives only bounded observation and self-body
snapshots, then selects `approach / pickup / eat`.

## Finite rules

- Each agent starts with FoodNeed 0.8; each tick adds 0.02, capped at 1.0.
- Food action begins at the finite FoodNeed threshold 0.5; below it, visible or
  held food does not by itself trigger approach, pickup or eat.
- Pickup reach is 8 world units. Eating lowers FoodNeed by 0.6, floored at zero.
- Pickup removes food from world and adds its ID to the actor's held-food list.
- Eat requires that exact held ID and removes it.
- Body revision changes with movement, FoodNeed or held-food state.
- History retry influence may alter only approach, never pickup or eat.
- InteractionHistory retains approach results only. Pickup/eat provenance stays
  in Godot resolution records and Timeline, not social relation history.

## Acceptance

The real Godot/HTTP check for NPC B produces:

```text
approach → approach → approach → pickup → eat
FoodNeed 0.80 → 0.20
```

After eating, food_01 is absent from world and held state. Inspector shows
`feeding`; Timeline records consumption. Three approach reports are accepted.
The same check proves tick-driven FoodNeed increase and Reset restoration.
Canonical capture may observe changed counts, but pending review keeps H at zero.

## Non-claims

This does not implement nutrition types, general inventory, spoilage, ownership,
competition, cooking, starvation, incapacitation, social meaning, sleep/energy
coupling, learned food choice, persistence, automatic H review, theta / M_delta /
T1, or canonical action authority. Constants are finite experiment parameters,
not Core primitives or final game-balance decisions.
