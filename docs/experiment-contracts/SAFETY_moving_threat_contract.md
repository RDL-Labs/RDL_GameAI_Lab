# Safety Moving Threat Contract

## Status

Finite opt-in experiment. The static Danger Gully remains the default Safety fixture.

## Boundary

Godot may replace the static danger zone with one moving dangerous object. The object owns a world position, a finite exposure radius, and a bounded severity label. After each accepted `flee` action it moves a fixed finite step toward the NPC's new position.

The Runtime receives only the current bounded danger candidate:

```text
danger_id
severity = low | medium | high
```

It does not receive exact threat position, velocity, pursuit direction, path prediction, or world truth outside the bounded exposure relation.

## Acceptance

```text
moving threat exposure
-> bounded danger candidate
-> dominant danger provenance
-> committed safe target
-> repeated flee/world changes
-> exposure clears
-> trajectory persists
-> committed safe target reached
-> COMPLETE / idle
```

The test must also show that the threat's Godot-owned world position changed while the Runtime kept the same Safety target contract.

## Explicit Non-Claims

- moving dangerous object != predator or villain ontology
- pursuit fixture != learned hunting behavior
- exposure != injury or incapacitation
- severity != fear, affect, or H
- threat movement != route planning or interception prediction
- Safety fixture state does not update canonical `M_B`, `H`, or T1 authority
- Energy cost, rescue, combat, and dynamic rho remain deferred
