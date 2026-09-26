# Luanti L0-L2 Bridge Contract

## Status

L0-L2 operational reference. Luanti 5.17.0 verified.

## Purpose

Establish Luanti as a replaceable World backend for the existing Python Runtime.

```text
Luanti World
-> finite observation adapter
-> POST /v1/observe
-> existing Runtime decision
-> finite Luanti action resolver
-> changed World state
-> subsequent finite observation
```

## L0 Environment

The repository owns a small `rdl_game` fixture, configuration, launch scripts,
and ignored local world/output directories. Luanti itself remains outside Git.
The install script copies only the fixture game into the selected Luanti tree.

The initial World contains one Lua entity agent (`npc_a`) and one ordinary Food
entity. It has no dependency on Godot data or scene state.

## L1 Observation Boundary

The v1 packet is agent scoped and finite:

```text
visible entities <= 16
visible regions <= 32
recent events <= 8
structured radius <= 12
```

It includes tick, adapter identity, self Body snapshot, bounded inventory,
relative entity position, finite distance, motion, and recent World results.
Lua ObjectRefs, hidden map state, and entities outside the observation radius do
not cross the adapter.

World facts are not converted into interpretation labels such as dangerous,
valuable, good, or bad.

## L2 Action Boundary

The resolver accepts the finite L0-L2 vocabulary:

```text
turn
move
approach
pickup
wait / idle
```

Each request is resolved against current Luanti state. Missing targets,
out-of-reach pickup, malformed direction/yaw, and unsupported actions produce a
bounded rejection event. An action request does not equal its World result.

## Authority

```text
Luanti state != NPC interpretation
Luanti entity ID != M_B relation
observation packet != RIB_B by identity
Runtime request != World consequence
Luanti action adapter != canonical evaluator
```

The existing Runtime owns its decision. Luanti owns position, entity existence,
pickup resolution, and the next observation. This phase does not add Sleep,
T1, Dynamic M_B, or behavior authority to the Luanti integration.

## Acceptance

1. Luanti starts reproducibly from repository scripts.
2. The single NPC receives only a bounded observation.
3. The existing Runtime returns `approach`, then `pickup` after a changed observation.
4. Luanti moves the NPC, resolves pickup, removes the Food entity, and records inventory.
5. A subsequent packet is generated from changed World state.
6. Godot source and existing Runtime semantics remain unchanged.
