# B1g renewable World, unchanged finite replacement rule

Baseline015d1ee. New separate environment condition: at each dawn after day1,
top up each original resource site to its initial stock. No new site, no changed
appearance, no actor-dependent or learning-dependent refill. Agents receive only
their normal present observations, never refill schedule or hidden stock.

Default renewable_food=false retains finite World. Original initial_food stays
constant. Record each dawn's actual addition and cumulative replenished_food;
at every operation initial+added = ground+carried+private stock+consumed.
Body/inventory/model/history remain continuous across dawn. This is an experimental
renewal schedule, not realistic plant growth or learned seasonal prediction.

Use both existing scenes, replacement disabled/enabled,4 continuous days. Same
Sleep, learning window,3+2 inspector, field gain and physical rules as B1f.
Do not tune refill or force adoption after seeing results. Preserve the B1f
finite-World material-shortage report. Separate model-specific prediction and
field counters from total counts to verify actual post-replacement usage.

Acceptance: renewal arithmetic/idempotent top-up, resource ledger, no body reset,
complete nights and operation counts. If replacement forms, validate disjoint
old/new evidence and reduced prediction scope. First-day actions match between
modes before replacement. Formation, usage, behavior difference and total food
are observations, not mandatory efficiency improvements.
