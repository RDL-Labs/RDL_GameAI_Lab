# Fixed Retry Sensitivity: Minimal Individual Difference

This is one GameAI-local response tendency in the Neural / Sensitivity design
layer. It is not a full personality, biological neural model, Core M_B, H, or
affect. Body and learned sensitivity remain outside this slice.

## Configuration

```powershell
python -m runtime.bridge --history-influence --retry-profile npc_a=long --retry-profile npc_b=short
```

Profiles are `short` (1 tick), `standard` (3 ticks), and `long` (5 ticks).
Unconfigured agents use standard, preserving the earlier retry experiment.
Assignments require history influence; duplicate agents and unknown profile
names are rejected at startup. The policy copies assignments into a read-only
mapping of frozen profiles. Changes require a new runtime experiment.

## Ownership and Influence

`runtime/sensitivity.py` owns profile definitions. They affect only the duration
of the existing no-progress retry window. The same history/context filtering,
current-visibility constraint, history retention and observation replay rules
remain in force. Results expose policy version `approach-retry-window-v2`,
`profile_id`, effective `retry_ticks`, and deferred-source IDs in inspection.

The profile does not rewrite history, canonical interpretation, assessment, or
H. Elapsed simulation ticks determine retry readiness, not wall-clock time.
At the exact retry boundary the target becomes eligible again. Profiles do
not imply danger sensitivity, trust, dislike, or learning speed.

## Evidence and Limits

With identical current packet and no-progress history at tick 1, a tick-2
decision approaches under short and waits under standard/long. Tests cover all
three exact retry boundaries, frozen configuration, default fallback, agent
isolation and invalid assignments. Body/sensitivity learning are not varied.

Godot 4.7.2 headless plus actual HTTP confirms short-profile behavior:
3 progress results -> 1 no-progress -> idle -> one Step -> approach and accepted
history result. The default and standard-profile live checks still pass.
The full suite passes 51 tests with `GODOT_BIN` set.

This establishes a configurable response difference, not completion of the
broader Neural/Body/Affect roadmap. Multi-dimensional sensitivity, learned
updates, emotion expression and social behavior require separate experiments.
