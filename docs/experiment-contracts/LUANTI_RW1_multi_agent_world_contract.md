# Luanti RW1 Multi-Agent World Contract

## Status

RW1 operational rich-World integration reference on Luanti 5.17.0.

## Purpose

Verify that two NPC bodies can coexist in one real Luanti World, send bounded
observations independently to one Runtime, and resolve separate actions without
sharing per-agent execution state.

```text
one Luanti World / one Runtime / one World tick
├-> npc_a observation -> approach food_a -> pickup food_a
└-> npc_b observation -> approach food_b -> pickup food_b
```

## Fixture Boundary

`multi_agent_food` is an isolated fixture mode. It does not alter the existing
ordinary Food or risky tasty Food fixtures. Each agent owns:

```text
in_flight
revision
held_food_ids
picked_up
assigned food target
```

The agents share only World time and spatial existence. Each bounded packet
contains the other NPC in `visible_agents`, but exposes only the observer's
assigned Food object in v1.

## Authority Boundary

RW1 reuses the existing Runtime Food decision. It adds no learning, arbitration,
canonical action authority, M_B-informed behavior, or inter-agent communication.

```text
coexistence != social relation
visibility != communication
independent action resolution != general scheduler
```

## Acceptance

1. NPC A and NPC B exist simultaneously in one real Luanti World.
2. Both send distinct agent-owned observation IDs to one Runtime.
3. Both observe the other agent through bounded `visible_agents`.
4. A approaches and picks up only `food_a`.
5. B approaches and picks up only `food_b`.
6. Neither agent's in-flight or inventory state blocks or mutates the other.
7. The canonical snapshot retains latest sections for both agents.
8. Existing L0-L3 and L7 real-Luanti regressions remain valid.
