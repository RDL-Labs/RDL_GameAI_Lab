# Minimal Sleep Life-Action Contract

**Status:** Opt-in bounded Sleep action operational

**Boundary:** Body recovery action only; no World Time model or Experience Consolidation

## Finite trigger and action

The first Sleep slice establishes:

```text
RestNeed >= 0.85
+ explicit finite sleep_window
+ visible safe rest-capable place
→ approach
→ sleep
→ Godot RestNeed recovery
→ subsequent bounded observation
```

Godot owns RestNeed, the explicit sleep-window fixture, place truth,
reachability, and recovery. Runtime receives only bounded body and place fields.
One bounded Sleep reduces RestNeed by `0.9`.
When the separate ActiveEnergy experiment is enabled, the same resolved Sleep
also restores a larger finite amount of ActiveEnergy. That body effect is
specified by the ActiveEnergy contract and still does not run consolidation.

Only a place described as `safe` is eligible. In the current World the policy
passes over uncertain `z_grove` and approaches safe Plaza. Outside the window,
below the threshold, or without a visible safe place, the action is `idle`.

## Separation

```text
bounded Sleep life action != Sleep Consolidation
explicit sleep_window != World Time model
RestNeed trigger != general sleep pressure model
sleep recovery != EnergyReserve / ActiveEnergy
Sleep Consolidation != T1
```

The Godot resolution records `sleep_kind=bounded_sleep` and
`consolidation=not_run`. No history is selected, compressed, forgotten,
associated, or admitted into canonical structures.

Food actions remain disabled in the isolated Rest/Sleep experiment. This
contract introduces no Food/Rest arbitration, Sleep Goal/Trajectory, routine,
night cycle, persistence, or learned safe-place relation.

## Evidence

- Runtime tests verify threshold, window, safe-place requirement,
  `approach / sleep / idle`, malformed state rejection, and sleeping expression.
- `sleep_http_check.gd` verifies the live chain: six world-changing approaches,
  safe-Plaza Sleep, RestNeed `0.86 → 0.00`, and `consolidation=not_run`.

The next Sleep boundary is not Consolidation by default. First decide whether
the game needs a persistent Sleep Goal/Trajectory or a minimal World Time
window. Either requires a separate finite contract.
