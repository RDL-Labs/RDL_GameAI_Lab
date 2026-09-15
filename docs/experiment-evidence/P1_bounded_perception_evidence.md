# P1 Bounded Perception Evidence

Evidence date: 2026-09-14

Migration note: this evidence predates the lab's Core v2.3 `RIB / RIB_B` resync. It remains valid for the bounded-perception claim. It does **not** claim that an observation packet is canonical `RIB_B`.

Repository target:

```text
RDL-Labs/RDL_GameAI_Lab
godot/rdl-game-ai-workbench/
```

Verified main at time of evidence:

```text
3819cbcb2d67f22b043c87fdc52d64ae800b1f9e
```

## Contract

P1 separates:

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

`mock_state_provider.gd` provides a mock world reference state and `get_observation(agent_id)` builds a bounded observation packet containing:

```text
observation_id
tick
agent_id
perception_rule
visible_agents
visible_objects
visible_places
```

`_build_decision_record(agent_id)` derives the mock action record from that bounded observation, not from a complete world-state argument.

`workbench_main.gd` can show the complete mock world for human inspection while separately showing the selected NPC's bounded observation and decision record.

## Acceptance Check

| Requirement | Current evidence | Status |
| --- | --- | --- |
| action selection receives bounded observation rather than full world reference state | decision construction calls `get_observation(agent_id)` and uses only bounded visible data | Pass for declared mock path |
| perception boundary and context are recoverable | observation includes `perception_rule`, tick, agent, visible entities | Pass |
| hidden world entities can remain outside agent observation | `far_cache` begins outside NPC A's perception radius | Pass |
| human inspector can see world reference and bounded observation separately | workbench presents them in separate views/panels | Pass |
| observation instance identity is recoverable | later update added `observation_id` and P2 distinguishes same-tick observations | Pass in current implementation |

## Core v2.3 Reading

P1 establishes only:

```text
engine reference != bounded agent observation
```

It does not establish:

```text
observation packet == RIB_B
```

Current P3 adds a separate acquisition adapter:

```text
bounded observation packet
↓ Purpose / finite B / selected dimensions / conditions / coverage / provenance
RIB_B
```

## Boundary Preserved

P1 evidence itself does not implement:

```text
canonical RIB_B acquisition
M_B
F / F'
E
H
M_Δ
T1 reconstruction
```

P1 remains accepted historical evidence for bounded perception and should not be inflated into later semantic claims.
