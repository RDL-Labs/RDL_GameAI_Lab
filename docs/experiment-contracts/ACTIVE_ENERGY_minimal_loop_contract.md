# Minimal ActiveEnergy Loop Contract

**Status:** Opt-in body loop operational

**Boundary:** Movement cost and Rest/Sleep recovery only; EnergyReserve is a separate contract and has no action authority

## Finite loop

```text
actual approach movement
→ ActiveEnergy -0.08

short rest
→ ActiveEnergy +0.25

bounded sleep
→ ActiveEnergy +0.75
```

Godot owns `active_energy` and applies each world/body change. The bounded body
snapshot exposes it only when the experiment is explicitly enabled. Values are
clamped to `[0, 1]`, and each changed value advances body revision provenance.

## Separation

```text
ActiveEnergy != RestNeed
ActiveEnergy != EnergyReserve
ActiveEnergy recovery != Sleep Consolidation
ActiveEnergy observation != Runtime action authority
```

The Runtime does not select actions from ActiveEnergy in this slice. The
separate EnergyReserve experiment does not transfer into this value. Food/Rest
arbitration, exhaustion effects, capacity, and canonical admission remain absent.

## Evidence

- `active_energy_loop_check.gd` verifies actual approach drain, smaller short-rest
  recovery, larger Sleep recovery, body snapshot visibility, and retained
  `consolidation=not_run` provenance.
- Existing Food, Rest, Sleep, rho, and canonical tests remain unchanged in
  authority and behavior when the experiment is disabled.
