# G2-B Multi-Agent Long-Life Contract

## Purpose

Verify that two agents can cross the G2-A day boundary in one Godot World and
one Runtime without sharing local life state or Dynamic `M_B` authority state.

## Per-Agent Path

```text
two real assisted Food successes
-> bounded Sleep
-> agent-owned shadow CandidateRelation
-> agent-owned explicit review / M_delta / T1
-> distinct M_B'
-> distinct cutover / REENTERED
-> cue-free next-day autonomous Food completion
```

The fixture runs NPC A and NPC B sequentially against shared World resources so
the provenance boundary is deterministic. It does not claim concurrent action
resolution, ecology, general scheduling, or need arbitration.

## Separation Requirements

```text
candidate A != candidate B
Experience A never enters bundle B
active model A != active model B
archive A does not replace archive B
M_delta A resolves independently from M_delta B
habit successes remain keyed by agent
```

## Acceptance

1. Both agents record two real assisted successes and become independently habit-ready.
2. Sleep produces one distinct sourced candidate per agent.
3. T1 expansion accepts only same-agent candidate and Experience materials.
4. Two parent models are archived and two reconstructed models become active.
5. Both `M_delta` states become `REENTERED` with no active rupture remaining.
6. With the shared cue disabled, both agents independently complete next-day Food.
7. Autonomous completions do not fabricate additional cue-bound success records.
