# Angular relation route field in native LW

Code `90d15f8`; [run 38353484984](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38353484984).
139 assertions PASS: base safety/Sleep 20, Python field correspondence 98,
route/proposal evidence 10, living invariants 8, living bounds 3.

Ports `relational_movement.scene/relation/compose` and the relational signature
in `directional_routes.admit`. Each observed route point retains up to five
unambiguous color/angle/range-band features. At least two common landmarks are
required. Pairwise angular errors are rotation-relative; incomplete, limited,
ambiguous or insufficient observations are not fabricated into a relation.
Range-band proxies near=4/mid=12/far=24 approximate bearing changes for each
existing physically feasible direction. They are not exact World coordinates.
Numeric costs match frozen Python examples, including partial/mixed/ambiguous
cases and direct-goal terms. Native direct goals retain their existing priority
gate rather than receiving the direct-goal term twice.

Successful actual delivery admits the experienced directional sequence. A reverse
sequence remains a zero-support proposal. Signatures distinguish the same colors
with different pairwise relations. Record bounds: 16 routes, 8 points, 5 features
per point, 32 diagnostic records. Old color-only specs remain available with
`--relation-field off` (default).

Native integration adaptation: comparable route directions enter the existing
BasicLoop as current feasible walk methods, priority 2.5 minus weighted relation
cost. Own method H and other current constraints still choose among them; unlike
Python's separate turn/step commands, native walking performs a checked turn and
step together. Physical movement success is not food/home goal success. Visible
direct food/home gates bypass remembered detours. No universal candidate language
or canonical T1 authority is introduced.

Three days, seed 20261005, renewable food, orientation on, Sleep apply/strata/
maintenance; hazard and food-body off:

| Relation field | Added | Ground | Stock A/B/C | Carried | Consumed |
|---|---:|---:|---|---:|---:|
| off | 102 | 42 | 33/80/35 | 6 | 6 |
| on | 98 | 48 | 53/35/56 | 0 | 6 |

Initial food=100; both conserve food and complete all nine Sleeps. Field methods
were selected A=925/B=17/C=28 times. Generated feasible proposals=5213/85/145;
route counts=12/14/14. These are selections, not distinct learned routes or proven
successful field steps. Different replenishment and actor outcomes preclude a
general efficiency claim. The living loop did form and use relational routes.

Remaining: richer coverage/landscape, full exploration/body continuity and the
other explicitly listed migration gaps. The pending long campaign predates this
feature; it cannot certify this latest combined state.
