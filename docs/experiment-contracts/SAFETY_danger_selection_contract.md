# Safety Danger Selection Contract

**Status:** Finite dominant-danger selection operational

**Boundary:** Bounded danger-source comparison only; no action or trajectory authority

## Finite rule

Godot reports only currently contacting danger sources:

```text
danger_id
severity: low | medium | high
```

The Runtime selector applies:

```text
high > medium > low
same severity: danger_id lexical order
```

The selected source is retained as decision provenance. It does not choose the
safe target, move the agent, change Energy, or define injury.

## Separation

```text
danger source truth != dominant danger selection
dominant danger != safe-target selection
danger severity != salience, H, injury, or personality
selection != trajectory authority
```

Moving threats, direction, velocity, route interaction, accumulated exposure,
and injury remain deferred.

## Evidence

- `high` wins over `medium` and `low`.
- ID provides deterministic ordering only at equal severity.
- Unsupported severity and duplicate source IDs are rejected.
- Existing Safety escape behavior remains unchanged with one high-severity
  Danger Gully source.
