# P2 Interaction Loop Evidence

Date: 2026-09-14

Migration note: this evidence predates the lab's Core v2.3 `RIB / RIB_B` resync. It remains valid for the actual action-to-subsequent-observation chain. It does not claim that either observation packet is already canonical `RIB_B`.

## Evidence Boundary

This evidence covers the minimal Godot Workbench interaction loop only.

It does not claim completion of canonical `RIB_B`, `M_B`, `F/F'`, `E`, `H`, Human Attention, relation history, learning, or T1 Reconstruction.

## Implemented Chain

```text
selected agent bounded observation packet
→ Python Runtime structured action
→ MockStateProvider.resolve_action()
→ selected agent position change
→ subsequent bounded observation generated from changed world state
→ Timeline / Decision Record display
```

## Files

- `runtime/core.py`
- `runtime/bridge.py`
- `godot/rdl-game-ai-workbench/scripts/workbench_main.gd`
- `godot/rdl-game-ai-workbench/scripts/mock_state_provider.gd`
- `godot/rdl-game-ai-workbench/tests/p2_interaction_loop_check.gd`

## Verification

Python runtime tests:

```text
python -m unittest discover -s tests
```

Godot parse/runtime smoke check used during original evidence:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path <workbench> --quit-after 1
```

P2 world-resolution check:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path <workbench> --script res://tests/p2_interaction_loop_check.gd
```

Observed original result:

```text
P2 interaction loop check passed
```

The check verifies that `approach(food_01)` changes the selected agent's position through `MockStateProvider.resolve_action()` and that a subsequent bounded observation id is recorded after the resolution.

It also verifies:

```text
source_observation_id != subsequent_observation_id
```

This preserves:

```text
same tick != same observation instance
```

before later phases introduce canonical acquisition and interpretation.

## Core v2.3 Reading

P2 establishes:

```text
action
→ actual world response
→ changed interaction conditions
→ later bounded observation packet
```

P2 does **not** establish:

```text
source observation == RIB_B(t)
subsequent observation == RIB_B(t+Δ)
```

Current P3 explicitly forms canonical diagnostic sections from accepted observation packets under finite Purpose / B.

Only after a future P4 supplies an explicit frozen pre-update `M_B` may two compatible sections form `F / F' / E`.

## Non-Goals Preserved

- No canonical `F/F'`, `E`, or `H` field was added by P2.
- Static structural conflict is not promoted to `E` or `H`.
- Human Attention is not implemented.
- The Runtime still receives only the bounded observation packet, not full world state.
- Current P3 acquisition sidecar remains read-only and cannot change the P2 action response.
