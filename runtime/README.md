# RDL GameAI Runtime

This is the minimal Python-side runtime boundary for the Godot workbench.

Current properties:

- localhost HTTP only
- Python standard library only
- bounded observation packet in
- structured action JSON out
- existing action policy unchanged
- read-only Core v2.3 canonical sidecar attached after accepted decisions
- canonical path currently reaches `RIB_B -> frozen M_B -> F/F' -> E`
- no unresolved review, `H`, `M_Δ`, T1 reconstruction, or canonical authority cutover yet

## Run

```bash
python -m runtime.bridge
```

```text
POST http://127.0.0.1:8765/v1/observe
GET  http://127.0.0.1:8765/health
GET  http://127.0.0.1:8765/v1/canonical-snapshot
```

## Existing action path

The runtime still selects an action from the accepted bounded observation. The canonical sidecar cannot modify that response.

```text
bounded observation
-> existing decide_action()
-> structured action response
```

The Godot workbench resolves the action, changes mock-world conditions, and generates a later bounded observation.

## Canonical acquisition

The raw observation packet is not canonical `RIB_B` by identity.

```text
accepted bounded observation
-> Purpose / finite B
   + selected dimensions
   + conditions
   + coverage
   + provenance
-> RIB_B
```

Current selected GameAI-local dimensions:

```text
visible_agents_count
visible_objects_count
visible_places_count
```

Missing selected coverage is not converted to zero.

## Frozen M_B / F / F' / E

For each exact finite context, the read-only sidecar creates one immutable diagnostic evaluator:

```text
agent
+ boundary id
+ Purpose
+ selected dimensions
+ conditions
-> frozen model_ref
```

The first model is intentionally simple: identity projection over the selected count dimensions. This is a finite experiment model, not a Core constant and not action authority.

```text
RIB_B(t)
-> same frozen pre-update M_B
-> F(t)

RIB_B(t+Δ)
-> same frozen pre-update M_B
-> F'(t+Δ)
-> E = Δ(F,F')
```

A change in finite context opens a different model/window. No E is formed across different contexts or different model refs.

The current E record remains:

```text
status = E-only-not-reviewed
```

It is not automatically unresolved and is not H.

## Snapshot

`GET /v1/canonical-snapshot` reports:

```text
authority = read-only-comparison-sidecar
stage = RIB_B-frozen-M_B-F-F_prime-E
latest RIB_B sections
finite diagnostic M_B records
latest interpretations
latest E records
xi_status = unrecovered-relations-remain
```

Core ξ remains qualitative; no runtime scalar is assigned to it.

## Current stop rule

The current runtime stops at E.

```text
implemented:
Observation -> RIB_B -> frozen M_B -> F/F' -> E

not implemented:
finite unresolved assessment
H_vec / H / θ
M_Δ
T1
canonical authority cutover
```

The next semantic step must classify E through an explicit finite assessment. Nonzero E alone is insufficient for H.
