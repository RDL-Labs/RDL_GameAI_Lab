# Load-limited climbing in the native living loop

2026-10-13 / implementation `d97871e`.

Optional low obstacles and optional climbing are separate switches. World barriers
block walking/running but not food/home/hazard vision. This is a finite low-object
adapter, not general vertical optics. Existing contact/message blocking remains
conservative. Native defaults preserve the prior World and actions.

Five local climb samples inspect crossed height, high-obstacle intersection and
landing clearance. The controller receives height/capacity/effort, not World IDs.
Capacity0.6*(1-damage)/(1+0.1*load), distance1*(1-damage); height tolerance1e-12.
Burst4*effort, reserve0.4*effort*RS and strain0.15*effort*SS match Python body rules.
Actual execution rechecks geometry and load; a blocked landing never becomes a
successful crossing. Sampled resistance remains midpoint-based.

Currently feasible climb candidates join existing food/home BasicLoop selection
only when the corresponding walking direction is unavailable. Alignment minus
effort is a fixed initial priority, not learned preference. Each climb has its own
method identity. Approaching the target can resolve method H while parent food/home
H remains unresolved. No forced detour success, safety success, food acquisition
or route reinforcement is credited for climbing alone.

## Evidence

[run38338277709](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38338277709)
passed43 assertions: safety16, climb geometry/load/method12, integrated invariants12,
actual climb correspondence3. The first attempted run hit ambiguous Julia numeric
syntax before simulation; `d97871e` corrected it and the complete suite reran.

Native seed20261005, three days, renewable food, three low barriers, flat ground,
hazards/running off. Climbing off/on share the same initial World.

| Climbing | Actual climbs A/B/C | Added food | Ground food | Private stock A/B/C | Consumed |
|---|---|---|---|---|---|
| off | 0/0/0 | 108 | 48 | 95/24/35 | 6 |
| on | 3/2/2 | 96 | 30 | 101/30/29 | 6 |

Initial food100, final carrying zero, both ledgers balance. Each run executed155,520
operations; all nine agent-night Sleep cycles completed. All seven climb attempts
were performed, one unit each; corresponding body delta mismatches were zero.
Stock154 ->160 is not a general efficiency result; resource additions differ under
the renewal rule and only one seed was compared.

A controlled visible-food/low-barrier specification used the same native entry,
clock and complete living loop for one day. A/C climbed once each; all12 food units
ended in private stores6/3/3, all Sleep cycles completed. This is a fixture within
the common loop, not another custom living simulation. Load5 passes height0.4,
load6 does not; landing blockage, high obstacle intersection and burst depletion
are local tests, not independent long-world cases.

[Native regression38338285060](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38338285060)
also passed. Seed04/05 results match run38334456523 after removing added null
climbing/running/ground diagnostics. Frozen-input replay remains verified.
No repository-wide suite or performance experiment was run.

## Remaining boundary

Drop and World cargo are next. Safety-climbing, learned preferences, general terrain
Sleep models and reinforcement of routes traversed by climbing remain unported.
Actual climb records are bounded to32 per agent with cumulative counters.
