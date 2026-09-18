# Minimal Safety Flee Contract

**Status:** Opt-in bounded danger-exit loop operational

**Boundary:** Static danger-zone exposure and visible safe-target escape only

## Finite loop

```text
NPC inside Godot-owned danger zone
→ bounded safety_context(exposed, danger_id, visible safe_target_id)
→ Runtime flee(safe target)
→ Godot world-position change
→ subsequent bounded safety observation
→ outside danger zone
→ idle
```

Godot owns zone geometry, agent position, containment truth, and movement
resolution. Runtime sees only the versioned bounded safety context and cannot
inspect hidden World state. The current fixture starts NPC B in Danger Gully and
exposes safe Plaza as the escape target.

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

Predators, moving threats, danger severity comparison, target selection among
multiple safe places, Energy cost, interruption, learning, injury, rescue, and
canonical admission remain absent.

## Evidence

- Runtime tests verify `flee / idle`, display-only `escaping` expression,
  malformed context rejection, and action-mode isolation.
- `safety_flee_http_check.gd` verifies the live chain:
  `flee → flee → flee → idle`, with the final observation outside Danger Gully.
