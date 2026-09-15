# P3 Canonical RIB_B Acquisition Evidence

Date: 2026-09-15

## Evidence Boundary

This evidence covers the first read-only Core v2.3 acquisition sidecar only.

It does not claim completion of agent `M_B`, `F/F'`, `E`, `H`, `M_Δ`, T1 reconstruction, or authority cutover.

## Implemented Chain

```text
accepted bounded observation packet
→ runtime.v23_acquisition.boundary_for_packet()
→ explicit finite Purpose / B
→ selected dimensions + conditions + coverage + provenance
→ GameAIRIBSection
→ read-only diagnostic snapshot
```

The bridge captures only after the existing `decide_action()` path has accepted the packet.

```text
existing action decision
→ read-only sidecar capture
```

The sidecar result is not used to alter the response.

## Files

- `runtime/v23_acquisition.py`
- `runtime/bridge.py`
- `tests/test_v23_acquisition.py`
- `.github/workflows/python-tests.yml`
- `docs/experiment-contracts/P3_rib_b_acquisition_contract.md`

## Current Finite Boundary

```text
Purpose:
  bounded-action-context

selected dimensions:
  visible_agents_count
  visible_objects_count
  visible_places_count

conditions:
  packet_schema
  perception_rule when available
```

These are demo-local selected dimensions and do not claim to exhaust GameAI interaction structure.

## Coverage Behavior

For each selected dimension the source list must be present.

```text
present empty list
→ valid zero count

missing / malformed selected source
→ section not formed
```

This prevents missing coverage from being silently converted into zero.

## Provenance

Each formed section records:

```text
section id
source observation id
tick
agent id
boundary id
Purpose
dimensions
conditions
coverage
adapter identity
xi_status = unrecovered-relations-remain
```

The qualitative `xi_status` does not numericize Core ξ.

## Read-only Stop Boundary

The snapshot explicitly reports:

```text
authority = read-only-acquisition-sidecar
stage = RIB_B-acquisition-only
not_implemented:
  M_B
  F
  F_prime
  E
  H
  M_delta
  T1
```

## Tests

Run:

```bash
python -m unittest discover -s tests -v
```

P3-specific tests cover:

- finite section formation;
- recoverable Purpose / B / selected dimensions;
- missing selected coverage rejection;
- custom finite boundary support;
- no input-packet mutation;
- no change to the existing action decision;
- explicit stop before `M_B / F/F' / E/H`.

A Python-only GitHub Actions workflow now runs the repository tests on pull requests and pushes to `main`.

Godot P2 acceptance remains a separate evidence boundary and is not claimed by the Python CI.

## Non-Claims

P3 does not establish that:

- the three selected counts are the agent's actual interpretation structure;
- observation packet and `RIB_B` are identical;
- the finite section is complete;
- `M_B` exists in the runtime;
- a canonical mismatch `E` has been formed;
- unresolved residual or H exists;
- passing tests proves the RDL model universally.

## Next Boundary

P4 must introduce an explicit finite frozen `M_B` evaluator and comparison compatibility rules before any `F/F'/E` formation.
