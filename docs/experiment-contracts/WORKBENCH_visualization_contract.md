# Workbench Visualization Contract

**Status:** V1-V3 operational; V4 Inspector reorganization deferred

**Responsibility:** Debug and observation rendering only

## Projection

The Workbench projects existing Godot World state and Runtime inspection into a
human-facing canvas:

```text
NPC                  -> circle; selected NPC gets an outer ring
ordinary object      -> small circle
moving threat        -> outlined triangle
place                -> translucent bounded circle
selected perception  -> thin observation-radius circle
committed target     -> dashed relation line and target ring
static danger zone   -> translucent red World-truth region
```

NPC labels and IDs remain available through tooltips. NPC circles retain the
existing click-to-select interaction.

## Data Boundary

`WorkbenchWorldView` receives a copied state snapshot, the selected agent ID,
and a target ID derived from existing Runtime inspection. It has no reference
to Runtime HTTP requests, action resolution, canonical sidecars, or policy
objects.

Safety and Rest target lines use their existing explicit trajectory target.
Base-Food uses the current action target only while the existing inspection
reports a committed life trajectory. No target, danger, observation, or agent
state is invented for display.

The danger-zone circle is Human-observer World truth. It is not added to the
NPC's bounded packet. Moving-threat exact position remains visible only on the
Workbench canvas and is not exposed to Runtime by this feature.

## Acceptance

- Entity kinds are distinguishable without text buttons.
- The selected NPC observation boundary is visible.
- An existing committed target is shown as a relation, not a new action.
- Static danger geometry and moving-threat motion can be observed.
- Visual refresh leaves World state and Runtime decision data unchanged.
- Existing Runtime, World-resolution, and canonical tests remain unchanged.

Art assets, animation, policy changes, rho expansion, Energy coupling,
canonical changes, and V4 Inspector reorganization remain outside this
contract.
