# Minimal EnergyReserve Loop Contract

**Status:** Opt-in body reserve operational

**Boundary:** Independent finite reserve with Sleep recovery only; no transfer or action authority

## Finite loop

```text
movement
→ ActiveEnergy decreases
→ EnergyReserve unchanged

short rest
→ ActiveEnergy recovers
→ EnergyReserve unchanged

bounded Sleep
→ ActiveEnergy large recovery
→ EnergyReserve +0.4
```

Godot owns `energy_reserve`, clamps it to `[0, 1]`, and exposes it only when
the reserve experiment is enabled. A changed reserve advances the body revision
and records `energy-reserve-v1` provenance.

## Separation

```text
EnergyReserve != ActiveEnergy
EnergyReserve != FoodNeed
reserve recovery != Sleep Consolidation
reserve state != action authority
```

This slice does not transfer reserve into ActiveEnergy, consume reserve during
movement, derive reserve from food, or constrain action at low values. Capacity,
metabolism, exhaustion, starvation, and Need arbitration remain deferred.

## Evidence

- `energy_reserve_loop_check.gd` verifies movement and short-rest invariance,
  bounded Sleep recovery from `0.4` to `0.8`, provenance, and
  `consolidation=not_run`.
- The existing ActiveEnergy Evidence continues to verify its independent
  movement and recovery loop.
