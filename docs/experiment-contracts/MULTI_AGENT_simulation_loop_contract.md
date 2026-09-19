# Multi-Agent Simulation Loop Contract

**Status:** Continuous-life Phase D operational

## Separation

Workbench simulation mode separates Human inspection from execution:

```text
selected_agent_id -> Inspector / Decision display only

simulation cycle
-> NPC A bounded packet -> decision -> World resolution
-> NPC B bounded packet -> decision -> World resolution
-> next World tick
```

Each Runtime policy continues to key trajectory, frozen decisions, results, and
Experience by agent ID. Godot continues to own each body snapshot and position.
The Workbench retains per-agent decision and resolution records for display.

## Movement Boundary

Enabling the simulation-agent loop disables the old sinusoidal mock wandering.
During this mode, NPC position changes only through accepted action resolution.
The debug wandering implementation remains available in the ordinary mock
Workbench path.

## Evidence

The finite two-agent test keeps NPC A selected in the Inspector. NPC A's fixed
cue response is `ignore`, while NPC B independently receives its own bounded
observation and performs `approach`. A remains fixed, B changes World position,
the selection remains A, and a later World tick adds no mock wandering.

This is sequential finite scheduling, not concurrency, general Need
arbitration, social interaction, or canonical multi-agent authority.
