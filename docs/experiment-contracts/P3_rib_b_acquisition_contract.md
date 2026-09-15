# P3 Canonical RIB_B Acquisition Contract

P3 introduces the first Core v2.3 semantic adapter in `RDL_GameAI_Lab`.

It converts an already accepted bounded observation packet into an explicit finite diagnostic action-section without treating the raw packet as canonical `RIB_B` by identity.

## Goal

Establish:

```text
bounded observation packet
!= canonical RIB_B
```

and form a finite section only through an explicit acquisition rule:

```text
bounded observation packet
↓ Purpose / finite B
selected dimensions
+ conditions
+ coverage
+ provenance
↓
RIB_B
```

## Current Boundary

Current Purpose:

```text
bounded-action-context
```

Current demo-local selected dimensions:

```text
visible_agents_count
visible_objects_count
visible_places_count
```

These dimensions are a first finite inspection surface. They are not Core-required GameAI variables and do not claim to exhaust the interaction.

Current finite conditions include:

```text
packet schema
perception rule when available
agent-specific boundary id
```

## Required Separation

```text
Engine world state
!= bounded observation packet
!= GameAIRIBSection
```

P3 does not create an agent interpretation merely by counting observed entities.

```text
RIB_B != F
```

## Coverage Rule

Every selected dimension must have an explicit source in the accepted observation packet.

If selected coverage is missing:

```text
missing / malformed source
→ section not formed
```

Invalid shortcut:

```text
missing selected source
→ 0
```

Zero is valid only when the selected source list is actually present and empty.

## Provenance Rule

Each section must preserve at least:

```text
source observation id
tick
agent id
boundary id
Purpose
selected dimensions
conditions
coverage
adapter identity
```

Core ξ is represented only by the qualitative statement:

```text
unrecovered-relations-remain
```

No numeric ξ runtime value is introduced.

## Authority Rule

The acquisition layer is diagnostic-only:

```text
authority = read-only-acquisition-sidecar
```

It may observe accepted packets after the existing action path validates them, but it must not:

- modify the packet;
- modify the chosen action;
- create or update agent policy;
- create `M_B`;
- create `F/F'`;
- create `E` or `H`;
- trigger `M_Δ` or T1.

## Acceptance Evidence

P3 is accepted when tests establish:

- explicit finite section formation from a bounded observation packet;
- Purpose / B / dimensions / conditions / coverage are recoverable;
- source observation identity is preserved;
- missing selected coverage is rejected rather than converted to zero;
- sidecar capture does not mutate the packet;
- sidecar capture does not change the existing action decision;
- snapshot explicitly states that `M_B / F / F' / E / H / M_Δ / T1` are not implemented.

## Stop Rule

Stop P3 once `RIB_B` acquisition is operationally sufficient under this finite test Boundary.

Do not continue into `F/F'/E` until P4 introduces an explicit finite frozen `M_B` evaluator and a comparison compatibility rule.
