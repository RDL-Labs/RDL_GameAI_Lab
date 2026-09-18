# ActiveEnergyCapacity Contract

**Status:** Opt-in finite body constraint operational

**Boundary:** Per-agent upper bound only; no speed, personality, or action authority

## Constraint

```text
0 < ActiveEnergyCapacity <= 1
ActiveEnergy <= ActiveEnergyCapacity
```

Godot owns the capacity. A valid capacity change immediately clamps current
ActiveEnergy and advances body revision provenance. Subsequent Rest and Sleep
recovery use the same upper bound. Invalid, non-finite, boolean, zero, and
out-of-range values are rejected without changing accepted state.

## Separation

```text
ActiveEnergyCapacity != ActiveEnergy
ActiveEnergyCapacity != EnergyReserve
capacity != movement speed
capacity != action authority
```

The first slice does not derive capacity from profile, injury, hunger, learning,
or canonical relations. It introduces no exhaustion behavior or reserve transfer.

## Evidence

- `active_energy_capacity_check.gd` configures capacity `0.6`, verifies immediate
  clamp, drains ActiveEnergy through real movement, and confirms bounded Sleep
  cannot recover above `0.6`.
- Invalid updates are atomic and leave capacity plus body revision unchanged.
