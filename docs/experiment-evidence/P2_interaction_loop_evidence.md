# P2 Interaction Loop Evidence

Date: 2026-09-14

## Evidence Boundary

This evidence covers the minimal Godot Workbench interaction loop only.

It does not claim completion of RDL GameAI, `EFP`, `M_B`, `F/F'`, `E`, `H`, Human Attention, relation history, learning, or T1 Reconstruction.

## Implemented Chain

```text
selected agent bounded observation
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

Expected result:

```text
Ran 3 tests
OK
```

Godot parse/runtime smoke check:

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\GitHub\RDL_GameAI_Lab\godot\rdl-game-ai-workbench --quit-after 1
```

Expected result:

```text
Godot starts without GDScript parse errors.
```

Known environment warnings about `user://logs` and Windows certificate store do not indicate a script parse failure.

P2 world-resolution check:

```text
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\GitHub\RDL_GameAI_Lab\godot\rdl-game-ai-workbench --script res://tests/p2_interaction_loop_check.gd
```

Observed result:

```text
P2 interaction loop check passed
```

This check verifies that `approach(food_01)` changes `npc_b`'s position through `MockStateProvider.resolve_action()` and that a subsequent bounded observation id is recorded from the resolution tick.

## Manual Workbench Check

1. Start the runtime:

   ```powershell
   python -m runtime.bridge
   ```

2. Open `godot/rdl-game-ai-workbench/project.godot` in Godot 4.7.
3. Run the project.
4. Select `NPC B`.
5. Switch mode from `Mock` to `Runtime`.
6. Confirm the Decision Record shows:

   ```text
   action: approach
   target: food_01
   World Resolution:
   before: (...)
   after: (...)
   next observation: obs-...
   ```

7. Confirm the Timeline includes a `resolved approach` event.

## Non-Goals Preserved

- No `E` or `H` field was added.
- Static structural conflict is not promoted to `E` or `H`.
- Human Attention is not implemented.
- The Runtime still receives only the bounded observation packet, not full world state.
