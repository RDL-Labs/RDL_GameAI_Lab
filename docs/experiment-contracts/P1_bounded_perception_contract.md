# P1 Bounded Perception Contract

P1 introduces the smallest agent boundary needed to act from limited observation instead of complete engine reference state.

This is an experiment contract, not an implementation of RDL Core semantics.

## Current Status

P1 is **accepted and retained** as pre-canonical interaction evidence under the current Core v2.3 roadmap.

Important migration reading:

```text
bounded observation packet != canonical RIB_B
```

P1 proves bounded perception. P3 separately defines how an accepted observation packet is acquired into a finite `RIB_B` under Purpose / B.

## Goal

Build an agent loop where action selection receives only an explicit perception packet.

The complete world state may exist for simulation and verification, but it must not be the direct input to action selection.

## Boundary

In scope:

- one small world reference state
- one or more mock agents
- explicit perception radius or sensor rule
- action selection from perceived data only
- recoverable logs showing what the agent could observe

Out of scope for P1 itself:

- canonical `RIB_B` acquisition
- `M_B`, `F`, `F'`, `E`, or `H`
- structural conflict to `E/H` evaluation
- Human Attention workflow or Human Attention load
- affect expression
- learning or T1 reconstruction
- Python connection
- optimized policy search
- LLM dialogue

## Required Separation

```text
engine/world reference state
→ perception boundary
→ agent observation packet
→ action selection
→ action
```

Invalid shortcut:

```text
engine/world reference state
→ action selection
```

The workbench may render complete state for human inspection. That does not grant the agent access to complete state.

Core v2.3 follow-on boundary:

```text
agent observation packet
↓ later P3 acquisition under Purpose / finite B
RIB_B
```

The observation packet is evidence/source material for that later acquisition step; it is not automatically the canonical section.

## Minimal State Shape

Engine reference state:

```text
tick
agents[]
objects[]
places[]
```

Agent observation packet:

```text
observation_id
tick
agent_id
visible_agents[]
visible_objects[]
visible_places[]
perception_rule
```

`observation_id` identifies an observation instance, not just a tick. Multiple observations may occur in the same tick when an action is resolved and the changed interaction conditions are observed again.

Action decision record:

```text
tick
agent_id
observation_summary
chosen_action
decision_reason
```

## Acceptance Evidence

P1 is accepted when evidence shows:

- action selection receives an observation packet, not full world reference state;
- perception boundary and relevant context are recoverable from logs;
- at least one object outside the boundary exists in world state but is absent from that agent observation;
- the workbench can show both world reference view and selected agent observation without merging them;
- deterministic replay under the declared test conditions reproduces the relevant observation/action records.

## Stop Rule

P1 stops when the current finite experiment Boundary is operationally sufficient to establish:

```text
agent behavior is mediated by bounded perception
```

Do not reinterpret that success as proof that canonical `RIB_B`, `M_B`, `F/F'`, `E`, or `H` already exist.
