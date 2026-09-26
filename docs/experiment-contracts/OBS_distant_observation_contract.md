# OBS-3 Distant Observation Contract

## Status

OBS-3 operational reference for the finite Luanti fixture.

## Boundary

`vision_distant` is an opt-in sensor channel owned by the observation adapter.
It does not change legacy observations, action selection, Experience, canonical
assessment, `M_B`, or T1.

The reference profile uses:

- range `(12, 64]`
- horizontal field of view `90` degrees
- vertical field of view `60` degrees
- `5` degree direction intervals
- one sample every four World ticks
- at most four coarse features per frame

Each feature contains only a frame-local ID, azimuth and elevation intervals,
coarse angular-size bands, and a coarse color band. Exact distance, World
coordinates, source object IDs, names, and persistent identity are forbidden.

## Geometry And Coverage

Range and field-of-view checks use the observer's current local frame. Fixed
opaque World nodes block a candidate. An unavailable or `ignore` voxel makes
the sample incomplete; it is never treated as transparent. The reference
fixture retries an incomplete sample rather than recording absence as fact.

The fixture is deliberately narrow: one visible muted-red fixed object, one
dark fixed object hidden by an opaque wall, and a later observer turn. It is
not general vision, image recognition, object identity, memory fusion, route
selection, or action authority.

## Acceptance

1. The forward sample exposes only the unoccluded coarse feature.
2. The wall-hidden object is absent.
3. Turning the observer away produces an empty later sample.
4. Stored frames contain no exact distance, World coordinate, source ID, or
   fixture object name.
5. Runtime rejects distant payload fields outside the finite schema.
6. The legacy decision path remains unchanged and the channel stays isolated.

