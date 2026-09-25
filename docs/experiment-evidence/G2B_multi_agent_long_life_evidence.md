# G2-B Multi-Agent Long-Life Evidence

## Command

```bash
python -m unittest -v tests.test_experience_godot.GodotExperienceTests.test_multi_agent_long_life_keeps_dynamic_mb_and_life_state_separate
```

Requires Godot 4.7.x through `GODOT_BIN`.

## Result

NPC A and NPC B each completed:

```text
day 1: assisted Food success x2
-> Sleep / candidate
-> independent Dynamic M_B cutover
day 2: cue-free autonomous Food completion
```

The final snapshot contained two active reconstructed models, two archived
parents, two `REENTERED` states, zero active `M_delta` states, and one adopted
same-agent candidate relation in each active model. Both agents remained
independently habit-ready. The shared World fixture did not merge Experience or
candidate provenance.

## Boundary

Actions are serialized for deterministic evidence. Concurrent scheduling,
resource competition, World Time, ecology, and canonical action authority remain
outside this reference.
