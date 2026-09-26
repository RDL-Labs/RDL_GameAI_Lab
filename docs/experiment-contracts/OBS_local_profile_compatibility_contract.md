# OBS Local Sensor Profile Compatibility Contract

## Status

OBS-2 operational reference on the RW2 Luanti fixture.

## Profile Registry

The finite Luanti registry contains two experimental local-vision profiles:

```text
fixture-sensor-default revision 1 -> legacy_radius_v1, radius 12
fixture-local-compact revision 1  -> legacy_radius_v1, radius 8
```

Agent assignment is resolved at run start. Unknown profiles and radii outside
the finite implementation boundary are rejected rather than silently clamped.
Shared profile definitions are read-only; observation results and execution
state remain agent-owned.

## Compatibility

The default profile replaces only the former fixed radius lookup. Existing
observation IDs, `perception_rule`, body/life context, reach distance, action
resolution, deposit causality, and Runtime policy remain unchanged.

Changing local vision radius is an intentional observation intervention. It
does not change pickup reach, movement step, reward sensitivity, personality,
theta, rho, or action authority.

## Acceptance

1. Default radius 12 preserves RW2 A/B Food life completion and radius counts.
2. With the same probe at distance 10, radius-12 A observes it and radius-8 B
   does not.
3. Both agents still complete pickup, return, deposit, and causal result
   admission in the intervention fixture.
4. No distant vision, FOV, occlusion, audition, p5 panel, or behavior use is
   introduced by OBS-2.
