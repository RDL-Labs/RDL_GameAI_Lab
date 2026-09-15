# RDL GameAI Workbench

This Godot project is the world / interaction surface for `RDL_GameAI_Lab`. It is not the canonical home of RDL semantics.

## Current boundary

- mock world reference state
- bounded per-agent observation
- optional localhost Python runtime bridge
- actual mock-world resolution for `approach(target_id)`
- subsequent bounded observation after changed conditions
- canonical v2.3 semantics remain on the Python read-only sidecar

```text
engine/world reference state
!= selected agent bounded observation
!= canonical RIB_B
!= M_B
```

## Run

Open `godot/rdl-game-ai-workbench/project.godot` in Godot 4.7 and run the configured main scene.

For the Python runtime:

```bash
python -m runtime.bridge
```

The workbench posts the selected agent observation to:

```text
POST http://127.0.0.1:8765/v1/observe
```

## Current interaction chain

```text
selected bounded observation
→ Python structured action
→ MockStateProvider.resolve_action()
→ changed world reference state
→ subsequent bounded observation
```

Only `approach(target_id)` currently changes the mock world. The provider records before/after positions and distinct source/subsequent observation ids.

## Canonical path

The observation packet sent by Godot is raw acquisition material, not `RIB_B` by identity.

On the Python side:

```text
accepted bounded observation
→ Purpose / finite B / selected dimensions / coverage / provenance
→ RIB_B
→ frozen diagnostic M_B
→ F / F'
→ E
```

This canonical sidecar is diagnostic-only and cannot change the action response.

Current E remains `E-only-not-reviewed`; no H is formed yet.

## Workbench controls

- `Run` advances ticks continuously.
- `Pause` stops ticking.
- `Step` advances one tick while paused.
- `Reset` returns the mock world to its initial state.
- `Mock` mode uses the built-in mock decision record.
- `Runtime` mode sends the selected NPC observation to the Python bridge and resolves the returned action.
- Clicking NPC A or NPC B changes the selected inspector target.
- World View may show more state for human inspection than the selected agent can observe.

## Structure

```text
scenes/
  main.tscn
scripts/
  workbench_main.gd
  mock_state_provider.gd
```

`mock_state_provider.gd` remains separate from the UI controller so later world adapters can replace it while preserving bounded observation and actual response semantics.
