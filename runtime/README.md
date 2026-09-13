# RDL GameAI Runtime

This is the minimal Python-side runtime boundary for the Godot workbench.

It is intentionally small:

- localhost HTTP only
- Python standard library only
- observation packet in
- structured action JSON out
- no `EFP`, `M_B`, `F`, `F'`, `E`, or `H` implementation
- no Human Attention workflow

## Run

From the repository root:

```powershell
python -m runtime.bridge
```

Default endpoint:

```text
POST http://127.0.0.1:8765/v1/observe
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

## Response

```json
{
  "agent_id": "npc_a",
  "action": {
    "type": "approach",
    "target_id": "food_01"
  },
  "inspection": {
    "observation_id": "obs-000012-npc_a",
    "runtime": "rdl-gameai-minimal-runtime",
    "reason": "first visible food object selected from bounded observation"
  }
}
```

This runtime is a PR1 bridge target. It does not apply actions back into the
world; that belongs to a later interaction-loop phase.
