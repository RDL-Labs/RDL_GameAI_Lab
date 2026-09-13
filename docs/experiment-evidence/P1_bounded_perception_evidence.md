# P1 Bounded Perception Evidence

Evidence date: 2026-09-14

Repository target:

```text
RDL-Labs/RDL_GameAI_Lab
godot/rdl-game-ai-workbench/
```

Latest verified GitHub main at time of evidence:

```text
3819cbcb2d67f22b043c87fdc52d64ae800b1f9e
```

## Contract

Contract file:

```text
docs/experiment-contracts/P1_bounded_perception_contract.md
```

P1 requires the workbench to separate:

```text
engine/world reference state
→ perception boundary
→ agent observation packet
→ action selection
→ action
```

from the invalid shortcut:

```text
engine/world reference state
→ action selection
```

## Implementation Evidence

Workbench files:

```text
godot/rdl-game-ai-workbench/scripts/mock_state_provider.gd
godot/rdl-game-ai-workbench/scripts/workbench_main.gd
```

`mock_state_provider.gd` provides a mock world reference state containing:

```text
tick
agents
objects
places
events
decision_records
```

`get_observation(agent_id)` builds a bounded observation packet containing:

```text
tick
agent_id
perception_rule
visible_agents
visible_objects
visible_places
```

`_build_decision_record(agent_id)` derives the mock action record from `get_observation(agent_id)`, not from a complete world-state argument.

`workbench_main.gd` shows the complete mock world in the 2D World View for human inspection, while separately showing:

```text
Bounded Observation
Decision Record
```

for the selected mock NPC.

## Acceptance Check

| Requirement | Current evidence | Status |
| --- | --- | --- |
| action selection receives an observation packet, not the full world reference state | `_build_decision_record(agent_id)` calls `get_observation(agent_id)` and uses visible item counts from that packet. | Static pass |
| perception boundary and relevant context are recoverable from logs | Observation panel prints `perception_rule`; decision record prints tick, agent, observation summary, action, and reason. | Static pass |
| at least one object outside the boundary exists in world state but is absent from that agent observation | World objects include `food_01` and `far_cache`; `far_cache` starts far from NPC A and the panel reports when visible object count is lower than world object count. | Static pass |
| workbench can show both world reference view and selected agent bounded observation without merging them | World View renders `places`, `objects`, and `agents`; Bounded Observation panel renders the selected agent packet separately. | Static pass |
| deterministic replay of same seed produces same observation and action records | Current mock provider uses fixed initial constants and deterministic tick updates. No Godot CLI execution evidence captured in this environment. | Needs runtime confirmation |

## Runtime Verification Gap

Godot CLI was not available in this environment:

```text
where.exe godot
INFO: Could not find files for the given pattern(s).
```

Manual Godot verification should check:

```text
1. Open godot/rdl-game-ai-workbench/project.godot in Godot 4.7.
2. Run the project.
3. Confirm the right column includes Bounded Observation and Decision Record.
4. Select NPC A and NPC B.
5. Confirm the observation panel changes with the selected NPC.
6. Press Step and confirm tick, observation, decision, and timeline update together.
7. Press Reset and repeat the same Step sequence to confirm deterministic replay.
```

## Boundary Preserved

The P1 workbench remains mock-only:

```text
no Python connection
no external dependency
no EFP implementation
no M_B implementation
no F / F' implementation
no E implementation
no H implementation
```

P1 should not move into affect, heat, relation history, or reconstruction until a concrete experiment break requires that scope.
