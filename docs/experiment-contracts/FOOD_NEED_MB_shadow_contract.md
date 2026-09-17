# FoodNeed M_B Shadow Comparison Contract

## Boundary

This default-off, in-process utility evaluates one explicitly formed FoodNeed
relation without registering it in the global canonical sidecar.

```text
validated Godot body snapshot
→ frozen food_need → visible_food_salience relation
+ bounded visible_food_count at t / t+Δ
→ shadow F / F' / E
```

It has no bridge endpoint, action authority, assessment ledger, H, theta,
M_delta, T1, graph mutation, or persistence.

## Window contract

- The caller explicitly opens a window with one source packet and Boundary.
- The source FoodNeed, source snapshot identity, relation rule, and model ref are
  immutable for the entire window.
- A window accepts one later observation and then becomes `compared`.
- Reuse, duplicate observation identity, earlier tick, agent/context mismatch,
  or malformed selected coverage rejects and closes the window.
- The sidecar retains at most 64 windows; capacity exhaustion fails closed.
- Missing values are never converted to zero.

## Interpretation

```text
visible_food_salience = frozen_food_need × visible_food_count
```

Both F and F' use the same pre-update FoodNeed. A valid later body snapshot may
be exposed as a next-model candidate with a distinct model ref; it never mutates
the compared model. A malformed later body candidate is recorded separately and
does not invalidate an otherwise valid frozen F/F' comparison.

## Acceptance evidence

`tests/test_food_mb_admission.py` proves:

- same RIB_B under separately preformed FoodNeed 0.2 / 0.8 models yields shadow
  salience 0.2 / 0.8;
- frozen FoodNeed 0.8 with visible food count 1 → 0 yields E = -0.8;
- later current FoodNeed 0.2 does not enter F'; it becomes a distinct candidate;
- invalid next-source state is isolated from the completed comparison;
- windows are single-use and capacity is finite;
- the default Boundary, bridge, action path, assessment and global sidecar remain
  outside this experiment.

## Non-claims

This does not establish promotion to the current canonical runtime profile,
automatic model updates, FoodNeed-driven canonical action, psychological hunger,
nutrition semantics, T1 reconstruction, or general relation-graph machinery.
