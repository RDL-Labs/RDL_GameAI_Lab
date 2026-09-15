# RDL GameAI Runtime

This is the minimal Python-side runtime boundary for the Godot workbench.

It remains intentionally small:

- localhost HTTP only
- Python standard library only
- bounded observation packet in
- structured action JSON out
- existing action policy remains unchanged
- read-only Core v2.3 acquisition sidecar attached after accepted decisions
- no agent `M_B`, `F`, `F'`, `E`, `H`, `M_Δ`, or T1 reconstruction yet
- no Human Attention workflow

## Run

From the repository root:

```bash
python -m runtime.bridge
```

Default endpoint:

```text
POST http://127.0.0.1:8765/v1/observe
```

Health:

```text
GET http://127.0.0.1:8765/health
```

Read-only canonical acquisition snapshot:

```text
GET http://127.0.0.1:8765/v1/canonical-snapshot
```

## Request

```json
{
  "observation_id": "obs-000012-001-npc_a",
  "tick": 12,
  "agent_id": "npc_a",
  "observation": {
    "visible_agents": [],
    "visible_objects": [
      {
        "id": "food_01",
        "kind": "food",
        "relative_position": [1.0, 0.0]
      }
    ],
    "visible_places": []
  }
}
```

## Existing Action Response

```json
{
  "agent_id": "npc_a",
  "action": {
    "type": "approach",
    "target_id": "food_01"
  },
  "inspection": {
    "observation_id": "obs-000012-001-npc_a",
    "runtime": "rdl-gameai-minimal-runtime",
    "reason": "first visible food object selected from bounded observation"
  }
}
```

The acquisition sidecar does not alter this response.

## Core v2.3 Acquisition Boundary

The bounded observation packet is **not** called canonical `RIB_B` by identity.

```text
accepted bounded observation packet
  ↓ gameai-v23-acquisition-v1
Purpose / finite B
+ selected dimensions
+ conditions
+ coverage
+ provenance
  ↓
RIB_B diagnostic section
```

Current selected demo-local dimensions:

```text
visible_agents_count
visible_objects_count
visible_places_count
```

If a selected source field is missing or not a list, the section is not formed. Missing coverage is not converted to zero.

Current sidecar output deliberately states:

```text
authority = read-only-acquisition-sidecar
stage = RIB_B-acquisition-only
not_implemented = M_B / F / F' / E / H / M_delta / T1
xi_status = unrecovered-relations-remain
```

`xi_status` is qualitative and does not assign a numeric value to Core ξ.

## Stop Rule

This stage is accepted only as an acquisition boundary. It does not claim that observation counts are an NPC's actual interpretation structure or that a canonical mismatch has been formed.

The next stage must introduce an explicit finite frozen `M_B` evaluator before any `F/F'/E` comparison is allowed.
