# Risky Tasty Food Reference Evidence

## Commands

```bash
python -m unittest -v tests.test_risky_tasty_food tests.test_territory_beast_world tests.test_territory_beast_multi_agent
python -m unittest -v tests.test_experience_godot.GodotExperienceTests.test_risky_tasty_food_world_projection_has_no_action_or_danger_authority
```

## Result

The opt-in Godot fixture exposes:

```text
ordinary_food: NORMAL
tasty_food: HIGH, territory_id=north_grove
beast_1
north_grove
God Statue external statement about tasty_food
```

No Food object contains `danger`, `dangerous`, or `threat_score`. The Runtime
reference sends three tasty approaches through the existing Territory Beast
fixture and observes `warning -> chase -> attack`, with medium physical injury.
The resulting direct Experience retains Food/Beast/territory/action provenance.

Ordinary Food produces no Territory event. Canonical sidecar state and game
action authority remain unchanged.
