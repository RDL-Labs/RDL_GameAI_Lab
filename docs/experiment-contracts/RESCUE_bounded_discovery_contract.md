# Rescue Bounded Discovery Contract

**Status:** Phase 5B finite observation slice  
**Scope:** another NPC can observe an incapacitated agent only inside its bounded perception

## Operational path

```text
World-owned incapacitation
-> another NPC enters perception range
-> visible_agents finite projection
-> condition = incapacitated
```

The World owns agent positions and BodyState. The observer receives only the
visible relation that the other agent is incapacitated. Exact injury level,
movement capacity, and danger exposure history are not included in the other
agent projection.

## Boundary

```text
visible incapacitated condition != global notification
visible incapacitated condition != Rescue Goal
visible incapacitated condition != action authority
```

An incapacitated agent outside the observation radius is absent from
`visible_agents`. Phase 5B does not add search, Rescue selection, carrying,
safe-place delivery, recovery, or social meaning.

The incapacitated agent's retained Safety trajectory is not resolved here.
Recovery must re-evaluate current relations; blind resumption is not admitted
by this contract.

## Acceptance

1. Incapacitated target outside the radius is not observed.
2. The same target inside the radius appears with the finite condition and schema provenance.
3. Private BodyState detail is not copied into the observer packet.
4. Runtime validates the finite vocabulary but does not form a Rescue action.
5. Existing decision, world resolution, canonical sidecar, H, and T1 behavior remain unchanged.
