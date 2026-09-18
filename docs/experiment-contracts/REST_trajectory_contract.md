# Rest Goal / Trajectory Contract

**Status:** Opt-in trajectory operational

**Boundary:** GameAI-local Rest commitment; generic interruption only

## Finite path

`RestTrajectoryPolicy` owns one process-local trajectory per agent:

```text
RestNeed >= 0.5 + visible rest point
→ Goal: restore_short_rest_capacity
→ GO_TO_REST with fixed target
→ optional SUSPENDED
→ resume same target
→ SHORT_REST
→ observed RestNeed recovery
→ COMPLETE and release
```

The target is selected once by the independent
[Rest Target Selection policy](REST_target_selection_contract.md) when the Goal
forms. Later observations do not reselect among candidates. If the target
disappears, loses rest capability, or becomes structurally unreachable, the
trajectory is `RELEASED`.

## Interrupt boundary

Version 1 accepts only finite generic interrupt candidates. Salience at or
above `0.7` suspends the trajectory with `idle`; clearing the interrupt resumes
the same target. Threat, Novelty, target switching, safety-based selection, and
interrupt-specific actions remain deferred.

`rest_safety` and coarse distance now participate only in the finite target
selection rule. They do not alter a committed trajectory. ρ remains unused.

## Authority and separation

- Runtime owns Goal/Trajectory commitment only.
- Godot owns RestNeed, place truth, movement, reachability, and recovery.
- The policy has no Sleep, consolidation, canonical `M_B`, H, or T1 authority.
- The policy is isolated from Base-Food and history action policies.
- Food/Rest Need arbitration remains forbidden in this contract.

Start the standalone bridge experiment with:

```text
python -m runtime.bridge --rest-trajectory
```

## Evidence

Python tests verify Goal formation, fixed target, suspension, same-target
resume, short-rest phase, completion, structural release, replay idempotence,
and conflicting observation-ID rejection.

`rest_trajectory_http_check.gd` verifies the live Runtime/Godot path through
generic suspension, same-target resume, repeated world-changing approach,
short rest, observed recovery, and `COMPLETE` release.

The next Rest boundary is a separately reviewed choice between extending
interrupt semantics or introducing multiple rest points and safety-sensitive
selection. Neither should be combined with Food/Rest arbitration yet.
