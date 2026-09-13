# RDL GameAI Workbench

This is the Godot-side P0/P1 workbench shell for `RDL_GameAI_Lab`.

It is not the game implementation. It is a minimal view / interaction / observation surface for future GameAI experiments.

## Current Boundary

- Godot-only runtime
- no Python connection
- no external dependencies
- mock state only
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

## Current Interaction

- `Run` advances ticks continuously.
- `Pause` stops ticking.
- `Step` advances exactly one tick while paused.
- `Reset` returns the mock world to its initial state.
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

This remains mock behavior only. It does not implement `EFP`, `M_B`, `F`, `F'`, `E`, or `H`.

## Structure

```text
scenes/
  main.tscn
scripts/
  workbench_main.gd       UI and interaction shell
  mock_state_provider.gd  Mock world, observation, and decision source; replace later with an experiment adapter
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
