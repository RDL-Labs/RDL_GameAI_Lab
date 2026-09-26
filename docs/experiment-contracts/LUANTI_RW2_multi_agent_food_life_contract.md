# Luanti RW2 Multi-Agent Food Life Contract

## Status

RW2 operational rich-World integration reference on Luanti 5.17.0.

## Purpose

Extend RW1 from independent acquisition to independent finite Food life cycles
inside one real Luanti World and one Runtime.

```text
npc_a: food_a -> pickup -> base_a -> deposit -> result_a
npc_b: food_b -> pickup -> base_b -> deposit -> result_b
```

Each agent owns its assigned Food, Base, inventory, stock, body revision,
in-flight request state, and result admission state. The Runtime reuses the
existing Base-Food policy and causally validates each deposit result against
that agent's registered deposit decision, source observation, cue, and Base.

## Bounded Observation

RW1's observer-relative radius remains in force. Each packet exposes only the
observer's assigned Food and Base, while other agents remain bounded spatial
observations. World lookup does not itself grant observation admission.

## Non-Scope

```text
dedicated resources != resource competition
coexistence != social coordination
two life cycles != general scheduling
result admission != Sleep or learning
Runtime Food policy != M_B-informed action
```

RW2 adds no danger, Rest, Sleep, T1, shared resource arbitration, or L10 action
authority.

## Acceptance

1. A and B complete pickup, return, and deposit in one World and Runtime.
2. A deposits only at `base_a`; B deposits only at `base_b`.
3. Runtime accepts exactly two causal life results, one per agent.
4. Result, source observation, and cue identities remain distinct by agent.
5. Canonical latest sections remain present for both agents.
6. RW1 radius boundary inclusion and exclusion remain valid after return.
