# RDL GameAI Workbench

This is the Godot-side P0/P1 workbench shell for `RDL_GameAI_Lab`.

It is not the game implementation. It is a minimal view / interaction / observation surface for future GameAI experiments.

## Current Boundary

- Godot workbench with mock mode enabled by default
- optional localhost Python runtime bridge
- no external dependencies
- mock state remains the world source for PR1
- no RDL semantic logic yet
- no `EFP`, `M_B`, `F`, `F'`, `E`, or `H` implementation

## Run

Open this directory in Godot 4.7:

```text
godot/rdl-game-ai-workbench/project.godot
```

Run the project. The configured main scene is:

```text
res://scenes/main.tscn
```

To try the optional runtime bridge, start the Python runtime from the repository
root before switching the toolbar mode from `Mock` to `Runtime`:

```powershell
python -m runtime.bridge
```

The workbench posts the selected agent's bounded observation to:

```text
http://127.0.0.1:8765/v1/observe
```

## Current Interaction

- `Run` advances ticks continuously.
- `Pause` stops ticking.
- `Step` advances exactly one tick while paused.
- `Reset` returns the mock world to its initial state.
- `Mock` mode uses the built-in mock decision record.
- `Runtime` mode sends the selected NPC's bounded observation to the Python bridge and displays the returned structured action.
- Runtime `approach(target_id)` actions are resolved through the mock world provider and update later observations.
- Click `NPC A` or `NPC B` in the 2D World View to update the Agent Inspector.
- The Bounded Observation panel shows what the selected mock NPC can observe.
- The Decision Record panel shows the latest mock action decision derived from that bounded observation.
- Each tick appends a simple mock event to the Timeline.

## P1 Bounded Perception Boundary

The workbench now separates:

```text
world reference state rendered for human inspection
!= selected agent bounded observation
!= mock decision record
```

Action decisions use the selected agent observation packet shape from:

```text
docs/experiment-contracts/P1_bounded_perception_contract.md
```

This remains bridge behavior only. It does not implement `EFP`, `M_B`, `F`, `F'`, `E`, or `H`.

## PR1 Runtime Bridge Boundary

The runtime bridge establishes only this path:

```text
selected agent bounded observation
→ localhost JSON POST
→ structured action response
→ workbench display
```

## P2 Interaction Loop Boundary

The workbench now has a minimal world-resolution path for runtime actions:

```text
bounded observation
→ runtime action
→ MockStateProvider.resolve_action()
→ changed world reference state
→ subsequent bounded observation
```

Only `approach(target_id)` changes the mock world. It moves the selected agent
toward a visible target and records the before/after positions in the Decision
Record and Timeline. This remains outside `EFP`, `M_B`, `F`, `F'`, `E`, `H`,
Human Attention, relation history, and reconstruction.

## Structure

```text
scenes/
  main.tscn
scripts/
  workbench_main.gd       UI and interaction shell
  mock_state_provider.gd  Mock world, observation, and decision source; replace later with an experiment adapter
runtime/
  Python localhost bridge and minimal observation-to-action boundary
```

## Future Adapter Boundary

`mock_state_provider.gd` is intentionally separate from the UI controller. A later experiment adapter can replace it as long as it provides equivalent state for:

- current tick
- agent list
- food/object list or equivalent observable objects
- bounded observation packet
- action decision record
- timeline events
- selected-agent lookup

Godot should remain a workbench surface, not the canonical home of GameAI semantics.
