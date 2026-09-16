# RDL GameAI Runtime

Individual retry experiment: `python -m runtime.bridge --history-influence --retry-profile npc_a=long --retry-profile npc_b=short`.
The [profile contract](../docs/experiment-contracts/SENSITIVITY_retry_profile_contract.md) defines fixed 1/3/5 tick response tendencies and their finite limits.

Optional history-to-action experiment: `python -m runtime.bridge --history-influence`.
This enables the [finite retry-window policy](../docs/experiment-contracts/EXPERIENCE_influence_contract.md).
Default startup retains the existing policy. The experimental decision cache
is limited to 128 observations per process and requires a fresh runtime afterward.

The [Experience history API](../docs/experiment-contracts/EXPERIENCE_history_contract.md) accepts `POST /v1/interaction-result` for admitted approach decisions and exposes `GET /v1/experience-snapshot`. Godot reports bounded outcomes automatically in Runtime mode. Storage is read-only with respect to action and canonical semantics.

Finite assessment is available at `POST /v1/assessment-review`; inspect IDs and revisions through `GET /v1/canonical-snapshot`. See [the current contract](../docs/experiment-contracts/CURRENT_v23_runtime_contract.md#finite-assessment-api) for request format, provenance, residual bounds, and retention. Diagnostic H is available per comparison and as retained residuals per exact context/frozen model.

This is the minimal Python-side runtime boundary for the Godot workbench.

Current properties:

- localhost HTTP only
- Python standard library only
- bounded observation packet in
- structured action JSON out
- existing action policy unchanged
- read-only Core v2.3 canonical sidecar attached after accepted decisions
- canonical path currently reaches `RIB_B -> frozen M_B -> F/F' -> E`
- explicit diagnostic residual review, per-comparison H, and retained H by finite context/model; no time decay, `M_Δ`, T1 reconstruction, or canonical authority cutover yet

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

The comparison path retains raw E; a separate explicit assessment forms per-comparison residual H.

```text
implemented:
Observation -> RIB_B -> frozen M_B -> F/F' -> E

not implemented:
time decay / θ
M_Δ
T1
canonical authority cutover
```

Finite assessment requires explicit reviewer, basis, and evidence. Nonzero E alone is insufficient for H. Snapshot `assessment.retained_H` sums the latest reviewed residuals per dimension within each exact context/model, then takes local L2. Re-review replaces a contribution; explicit resolution removes it. There is no time decay, signed cancellation, cross-context total, or restart persistence. The contract specifies retention limits and repeated-event accounting.
