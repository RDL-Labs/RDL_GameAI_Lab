# Minimal Rest Loop Contract

**Status:** Opt-in isolated loop operational

**Boundary:** Godot-owned RestNeed and short-rest world resolution; no Sleep or consolidation

## Operational loop

The first Rest behavior slice establishes one finite chain:

```text
enabled tick
→ RestNeed increases
→ Runtime sees bounded body + visible rest point
→ approach until within reach
→ rest
→ Godot reduces RestNeed
→ subsequent bounded observation
```

Godot owns `rest_need`, reachability, place capability, and recovery resolution.
Runtime receives only the bounded body snapshot and visible-place fields. The
finite threshold is `0.5`; one short rest reduces RestNeed by `0.6` without
exposing or modifying the ρ Rest projection fixture.

## Isolation

This slice is explicitly opt-in. Enabling Rest actions disables Food actions so
the experiment does not silently introduce a need-priority policy. Packets with
both action modes enabled are rejected.

The operational state is separate from the diagnostic ρ source:

```text
RestNeed != rho_rest
short rest != sleep
sleep != Sleep Consolidation
Sleep Consolidation != T1
```

There is no long sleep, sleep pressure, time-of-day rule, safety choice between
multiple sites, experience consolidation, persistence, Goal/Trajectory state,
or canonical admission in this contract.

## Evidence

- Python Runtime tests cover `approach / rest / idle`, recovering expression,
  malformed RestNeed, and Food/Rest coactivation rejection.
- `rest_minimal_loop_check.gd` verifies tick increase, finite approach, short
  rest resolution, provenance, and RestNeed decrease in Godot.
- `rest_http_check.gd` verifies the live localhost chain from Runtime decisions
  through repeated Godot world changes to `rest` and recovery.

The next behavior boundary is explicit Rest Goal/Trajectory ownership and
interruption/recovery rules. Sleep remains a later, separately contracted
world action and consolidation window.
