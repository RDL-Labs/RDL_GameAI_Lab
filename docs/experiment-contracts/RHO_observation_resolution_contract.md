# ρ Observation Resolution Contract

**Status:** Food projection slice operational  
**Boundary:** Godot-local observation projection; no Runtime policy or canonical admission

## Operational slice

`ObservationResolutionAdapter` projects one unchanged Godot Food world state
into three finite distinction schemas:

| Level | Distinctions |
|---|---|
| LOW | `enough / needs_supply` |
| MID | `enough / low / critical / empty` stock band |
| HIGH | stock band + trend + bounded Food-site condition |

Every projection includes `profile_id`, domain, level, rule version, and an
explicit GameAI-local authority boundary. It contains no exact Base stock.
Unsupported levels fail closed.

## Non-intervention

The first slice is diagnostic only. Calling the adapter does not change:

- Godot world state or Base stock;
- the existing default life context;
- Runtime action decisions;
- FoodNeed shadow or default canonical sidecars;
- assessment, H, T1, or action authority.

The current Runtime bridge does not consume this projection. Action differences
are deliberately outside this Acceptance.

## Evidence

`rho_food_projection_check.gd` evaluates LOW, MID, and HIGH against the same
provider state. It verifies distinct finite schemas, no exact-stock leakage,
invalid-level rejection, authority provenance, and unchanged world/default
context before and after projection.

## Next boundary

Add a versioned profile-selection contract before attaching ρ projection to
normal observation packets. After that non-intervention check, reuse the
Adapter structure for the minimal Rest / Sleep context. Learning, DNA, Neural
derivation, salience changes, and canonical admission remain deferred.
