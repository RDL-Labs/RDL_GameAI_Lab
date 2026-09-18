# Minimal Safety Flee Contract

**Status:** Opt-in bounded safe-target trajectory operational

**Boundary:** Static danger-zone exposure and committed visible safe-target escape only

## Finite loop

```text
NPC inside Godot-owned danger zone
→ bounded safety_context(finite danger sources, finite safe candidates)
→ Runtime flee(safe target)
→ Godot world-position change
→ subsequent bounded safety observation
→ outside danger zone, same target retained
→ safe target reached
→ idle
```

Godot owns zone geometry, agent position, containment truth, and movement
resolution. Runtime sees only the versioned bounded safety context and cannot
inspect hidden World state. The current fixture starts NPC B in Danger Gully and
exposes safe Plaza and uncertain Grove as bounded candidates. The independent
[Safety Target Selection contract](SAFETY_target_selection_contract.md) selects
Plaza. `SafetyTrajectoryPolicy` fixes that target once, continues after zone exit, and completes only when Godot reports
the bounded `safe_reached` position fact and its `reached_safe_target_id`.
Completion requires that identity to equal the committed target.
The independent [Safety Danger Selection contract](SAFETY_danger_selection_contract.md)
selects the dominant bounded danger source for provenance without changing the
escape-target rule.

## Isolation

Safety action mode is opt-in and disables Food, Rest, and Sleep action modes.
The first selector has exactly one authority: when exposed and given a visible
safe target, emit `flee`; otherwise emit `idle`.

```text
danger exposure != Threat personality response
flee != generic approach
safe target != guaranteed global safety
danger exit != injury or recovery
Safety != Energy authority
```

Moving threats are outside this static-zone contract and are isolated in the
[Safety Moving Threat contract](SAFETY_moving_threat_contract.md). Predator
ontology, danger-direction and route comparison, Energy cost, interruption,
learning, injury, rescue, and canonical admission remain absent.

## Evidence

- Runtime tests verify `flee / idle`, display-only `escaping` expression,
  malformed context rejection, and action-mode isolation.
- `safety_flee_http_check.gd` verifies the live chain: six `flee` actions followed
  by `idle`, with the final observation outside Danger Gully and at safe Plaza.
- Policy tests verify danger-exit persistence, fixed-target completion,
  mismatched reached-target rejection, structural release, and frozen
  observation replay.
