# Phase 3 Energy Reference Evidence

**Status:** Closed operational reference; coupling and behavior expansion deferred

**Evidence date:** 2026-09-18

## Established boundary

The minimal Energy body model is operational as three separate finite values:

```text
actual movement
→ ActiveEnergy decreases

short rest
→ ActiveEnergy small recovery
→ EnergyReserve unchanged

bounded Sleep
→ ActiveEnergy large recovery, capped by ActiveEnergyCapacity
→ EnergyReserve finite recovery
→ consolidation remains not_run
```

Godot owns all three values and their world/body resolution. They are exposed
only in explicitly enabled experiments. Runtime action authority, canonical
admission, and Sleep Consolidation remain unchanged.

## Controlled results

The real Godot checks establish:

```text
ActiveEnergy movement sequence: 1.00 → 0.20
short-rest recovery:            0.20 → 0.45
bounded-Sleep recovery:         0.20 → 0.95

EnergyReserve movement/rest:    0.40 → 0.40
EnergyReserve bounded Sleep:    0.40 → 0.80

configured capacity:            0.60
ActiveEnergy after movement:    0.44
ActiveEnergy after Sleep:       0.60
```

Invalid capacity updates are rejected atomically. The full suite passes 140
tests, including live Godot/HTTP Food, Rest, Sleep, rho, and canonical checks.

## Established separations

```text
ActiveEnergy != EnergyReserve
ActiveEnergy != ActiveEnergyCapacity
Energy state != action authority
Energy recovery != Sleep Consolidation
Energy body values != canonical M_B by identity
```

The values may later participate in explicitly admitted finite relations. This
reference does not perform that admission.

## Deferred expansion

- reserve-to-active transfer;
- metabolism or FoodNeed coupling;
- exhaustion, speed reduction, or action blocking;
- dynamic capacity from injury, profile, or learning;
- running and differentiated movement costs;
- Need arbitration;
- canonical admission.

## Reopen criteria

Reopen Phase 3 only for a named game feature that needs one of the deferred
relations. Safety / Danger may observe bounded Energy context later, but it must
not silently define Energy ownership or mutate these contracts.
