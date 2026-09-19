# Food-Rest Continuous-Life Contract

**Status:** first finite integration slice

## Integrated chain

`FoodRestCoordinator` is the only authority in this slice allowed to receive a
packet with both Food and Rest actions explicitly enabled.

```text
committed Food trajectory + held food
-> bounded RestNeed reaches 0.85
-> Food retained / FOOD_SUSPENDED
-> RestTargetSelectionPolicy selects Rest Hut once
-> approach / short rest
-> observed RestNeed below Rest completion threshold
-> current packet returned to BaseFoodLifePolicy
-> RESUME or RELEASE
```

The first live fixture starts with low RestNeed so Food can reach pickup. It
then raises RestNeed to the finite experiment threshold. Rest Hut is distinct
from Plaza/Base; after short rest the same NPC must travel back to Plaza before
deposit can complete.

## Finite arbitration rule

The v1 comparison is intentionally narrow:

```text
rest_need >= 0.85 -> Rest temporarily preempts Food
otherwise          -> Food remains active
```

This threshold is a fixture parameter, not biology, personality, affect, rho,
canonical M_B, H, or a general Need arbitration model. The coordinator does not
restore an old action. It preserves the Food trajectory and asks the Food policy
to decide again from the current bounded packet after Rest completes or releases.

## Exclusions

Safety coactivation, Sleep, Energy authority, dynamic priority, starvation,
injury, rescue, canonical admission, H, and T1 remain outside this slice.
