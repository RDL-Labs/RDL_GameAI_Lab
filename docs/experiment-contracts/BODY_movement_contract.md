# Body Movement: Finite Capability Experiment

Godot owns each agent's `movement_scale` and revision. The Agent Inspector's
Movement menu sets full (1), limited (0.5), or stopped (0) for the selected agent.
This is an explicit experimental intervention, not a model of injury or fatigue.
Reset restores all agents to full capability.

## Boundary and Ownership

Runtime packets optionally contain `observation.body` with `agent_id`,
`snapshot_id`, `revision`, and `movement_scale`. Godot projects only the selected
agent's own body state. Python accepts finite numeric scales in [0,1], verifies
owner identity and basic snapshot/revision shape, and returns the snapshot
reference in `inspection.body`. This is a reported self snapshot, not independent
proof of world state. Missing body preserves legacy behavior; it is not inferred
as evidence of health. Snapshot identity is local to the current run.

The action path returns idle when a reported zero capability would otherwise
produce approach. The constraint is applied after the optional history policy
too, so a visible alternative cannot bypass it. Positive scales preserve the
chosen action; Godot enforces actual approach displacement capped at
`36 * movement_scale`. Scripted ambient movement is scaled separately per tick,
and stopped agents do not move in that path either. This is mock movement, not
a physical velocity/acceleration model.

Godot enforces its current body state even if a stale approach arrives. Movement
menu changes cancel local outstanding requests and request a fresh observation.
Cancellation does not roll back already admitted server decisions/results.
Body changes advance the revision but do not rewrite history or sensitivity.
Under the experimental replay policy, a changed body requires a new observation
ID. Runtime restart is still required after resetting Godot's observation IDs.

## Semantics

Body is a GameAI-local action condition. It is not canonical M_B, H, or an emotion.
The current canonical evaluator still selects only visible entity counts; body
changes alone do not form a count mismatch or add H. Later world/visibility
changes may naturally produce E under the existing comparison contract.
Recovery does not erase prior no-progress history or its active retry window.

## Evidence

Five Python tests cover stopped/limited/full decisions, invalid and wrong-owner
snapshots, history-alternative constraint enforcement, fresh-ID recovery, and
canonical non-interference for an otherwise identical observation.
Actual Godot 4.7.2 + HTTP verifies stopped displacement 0, recovered displacement
36, limited displacement 18, accepted movement history, stopped ambient movement,
other-agent isolation, and reset restoration. All 57 tests pass with GODOT_BIN.
Interactive visual layout has not been inspected. Learned bodily dynamics,
damage/recovery simulation, energy consumption, and affect remain deferred.
