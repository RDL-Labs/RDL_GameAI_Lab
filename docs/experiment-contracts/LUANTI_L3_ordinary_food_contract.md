# Luanti L3 Ordinary Food Contract

## Status

L3 operational reference on Luanti 5.17.0.

## Purpose

Run the existing assisted Base-Food Goal and Trajectory semantics against a
Luanti-owned World.

```text
coarse low-stock cue
+ bounded low-stock observation
+ visible ordinary Food
-> existing BaseFoodLifePolicy
-> GO_TO_SITE
-> GATHER
-> RETURN_BASE
-> DEPOSIT
-> Luanti stock change
-> causal life-result admission
```

## World Ownership

Luanti owns the NPC and Base positions, Food entity existence, held inventory,
coarse Base stock source, movement, pickup, and deposit resolution. The Runtime
receives only the existing coarse stock band, source-bearing cue, known Base ID,
at-Base relation, visible Food, and bounded self Body snapshot.

The exact `base_food_stock` value never enters the packet.

## Runtime Reuse

L3 uses `python -m runtime.bridge --base-food-life`. It does not add a Luanti
specific policy. The existing Runtime fixes the Food target and returns
`approach`, `pickup`, `approach base`, and `deposit` from successive packets.

On successful deposit, Luanti sends `/v1/life-result` with the registered source
observation and cue ID. Existing causality checks admit the result and complete
the trajectory.

## Separation

```text
Luanti exact stock != observed stock band
God Statue cue != action command
Runtime deposit request != successful deposit
successful deposit != admitted result without provenance
L3 result != canonical M_B, E, H, or T1
```

## Acceptance

1. Low stock and visible Food form the existing replenishment Goal.
2. Luanti resolves approach and pickup from current World state.
3. Held Food causes return to the fixed Base.
4. Luanti resolves deposit only at the Base with held Food.
5. The result binds to the registered deposit decision and cue provenance.
6. Exact stock remains inside Luanti and Godot code remains unchanged.
