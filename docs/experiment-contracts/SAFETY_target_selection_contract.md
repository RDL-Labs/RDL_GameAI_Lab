# Safety Target Selection Contract

**Status:** Finite multi-candidate selection operational

**Boundary:** Candidate comparison only; no trajectory persistence or World truth authority

## Finite rule

Godot emits bounded candidate descriptions:

```text
target_id
safety: safe | uncertain
distance_band: within_reach | near | far
```

The Runtime selector applies:

```text
safe > uncertain
same safety: within_reach > near > far
remaining tie: target_id lexical order
```

The selector returns one candidate and finite provenance. It does not move the
agent or retain a target. `SafetyTrajectoryPolicy` consumes the selection once
and owns subsequent commitment.

## Separation

```text
candidate description != selection
selection != trajectory
trajectory != World position
safe attribute != universal or permanent safety
```

Danger direction, route closure, moving threats, path cost, Energy, injury,
learning, and rho are not selection dimensions in this version.

## Evidence

- A farther `safe` candidate wins over a nearer `uncertain` candidate.
- Distance breaks ties only at equal safety.
- Duplicate IDs and unsupported distinctions are rejected.
- Reversing candidate ranks after commitment does not reselect the active
  Safety target.
