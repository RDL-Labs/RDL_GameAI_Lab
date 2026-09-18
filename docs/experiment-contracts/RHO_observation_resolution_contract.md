# ρ Observation Resolution Contract

**Status:** Food projection and versioned profile selection operational

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

`ObservationResolutionProfile` owns only the finite agent/domain assignment.
Its `rho-profile-selection-v1` contract supports the `food` domain, uses MID as
the explicit default, and permits LOW/MID/HIGH assignments. Configuration is
atomic: an unsupported domain or level rejects the whole candidate without
replacing the last accepted assignment. Selection provenance records the
profile version, agent, domain, level, and whether the level was explicit or
defaulted.

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

`rho_profile_selection_check.gd` fixes `npc_a: food LOW` and `npc_b: food HIGH`
against one unchanged World. It verifies distinct selected schemas, versioned
provenance, atomic rejection, and non-intervention in World and life context.

## Next boundary

Normal observation packets still do not include this projection. Before that
connection, decide the finite packet field and preserve legacy packet behavior
for unconfigured runs. Then reuse the Adapter structure for the minimal Rest /
Sleep context. Learning, DNA, Neural derivation, salience changes, true temporal
trend, and canonical admission remain deferred.
