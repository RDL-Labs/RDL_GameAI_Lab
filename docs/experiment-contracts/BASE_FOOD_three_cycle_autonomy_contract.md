# Base-Food Three-Cycle Autonomy Contract

**Status:** Continuous-life Phase C operational

## Continuous Experiment

One NPC, one Runtime process, and one Godot World instance complete:

```text
cycle 1: finite cue -> collect -> return -> deposit -> admitted success 1
cycle 2: finite cue -> collect -> return -> deposit -> admitted success 2
cycle 3: cue disabled -> low stock -> learned trigger -> collect -> return -> deposit
```

No success result is inserted before the experiment. Cycles 1 and 2 reach the
normal Godot deposit resolution and `/v1/life-result` admission path. Cycle 3
must report `cue = null`, `goal_trigger = learned_low_stock_relation`, and at
least two retained successes before its first action.

## World Continuity

The Workbench and Runtime are not reset between cycles. Base stock returns to a
shortage through the existing per-tick consumption. Because the minimal World
has no ecology or exploration simulation,
`MockStateProvider.replenish_food_site(agent_id)` supplies the next finite Food
object inside that agent's bounded observation only after the prior object was
gathered. This controlled placement prevents the test from inventing hidden-site
navigation. It is an explicit World fixture transition, not an NPC decision,
learning rule, or canonical update.

Exact result replay, frozen observation replay, and World updates retain their
existing independent tests. Phase A guarantees replay cannot clear a later
trajectory or increment habit evidence.

The two-success threshold remains a finite experiment boundary, not a general
habit or biological learning model.
