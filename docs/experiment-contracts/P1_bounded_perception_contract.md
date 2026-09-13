# P1 Bounded Perception Contract

P1 introduces the smallest agent boundary needed to act from limited observation instead of complete engine reference state.

This is an experiment contract, not a semantic implementation of RDL Core.

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

Out of scope:

- `EFP`, `M_B`, `F`, `F'`, `E`, or `H` implementation
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

Enterprise-derived constraints carried forward:

```text
Structural Conflict != E != H
Human Attention load != H
```

For later phases, structural conflict may matter only after an actual interaction changes later conditions and produces a subsequent bounded observation / `EFP'` that can be interpreted with the same pre-update `M_B`.

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

P1 is accepted only when evidence shows:

- action selection receives an observation packet, not the full world reference state.
- perception boundary and relevant context are recoverable from logs.
- at least one object outside the boundary exists in world state but is absent from that agent's observation.
- the workbench can show both the world reference view and the selected agent's bounded observation without merging them.
- deterministic replay of the same seed produces the same observation and action records.

## Stop Rule

Stop P1 when the current finite boundary is operationally sufficient to prove:

```text
agent behavior is mediated by bounded perception
```

Do not continue P1 into affect, heat, relation history, Human Attention, or reconstruction unless a concrete break requires it.
