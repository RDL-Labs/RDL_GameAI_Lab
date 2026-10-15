# Easy nearby food / parent-H breadth comparison

2026-10-14. Three actors, three continuous human-scale days, same scene and
configuration for parent-breadth off/on. Existing integrated Julia LW loop.

Camp (0,4); food (0,17), distance13, outside food visibility radius12.
All three starting positions are outside that radius. A short approach can reveal
food; its position is not injected into policy. Camp beacon range60 is used
(skyline mode off); tower at(-4,4), radius0.3, height12. No hazards, low obstacles,
landscape resistance, or ground patches. Initial reserve90 and inventory2 each.
Other learning, route, body and social settings inherit the saved optimization spec.

The site holds1,000,000 units. Even pickup on all155,520 actor operations cannot
empty it. This is operationally inexhaustible within this finite experiment,
not a new infinite-stock World representation. No replenishment or resource-ledger
exception is introduced. All consumed/deposited/carried food remains accounted for.

Initial distance/non-exhaustion bounds and per-run operation count, positive final
ground stock and food conservation are asserted (9 assertions total).
Evidence: `outputs/easy-food-1/{off,on}-{spec,result,summary}.json`.

This is deliberately an easier alternative environment, not a one-variable
comparison with the previous harsh World. Runtime order is off then on in one
process; compile/cache effects prevent interpreting times as a speedup estimate.

## Observed outcome

Both runs completed all155,520 operations and the9 assertions passed.
Both acquired zero food. Ground remained1,000,000; initial carried6 were consumed.
All9 actor-nights completed Sleep. Identical action counts in both conditions:

|Actor|walk operations|scan operations|rest operations|
|---|---:|---:|---:|
|A|20|5|51,810|
|B|19|3|51,813|
|C|17|3|51,815|

Each also deposited once, retrieved twice and ate twice. Those transfers concern
initial inventory, not harvested resources. A selects exploration method `rest`
at81 seconds and again at the next exploration start. Total travel was only
10/9.5/8.5 units for A/B/C in the disabled condition.

Enabled breadth:77,227 decisions, full-width77,208 (about99.98%), restricted11.
540,571 offered vs540,530 admitted candidate entries. The easier scene did not
produce a low-H routine. It exposed a rest-dominated unresolved food goal in both
conditions. Food proximity alone does not establish discoverability by the current
policy or successful commuting.

Code context: performed `rest` satisfies the child question `rested`, while the
food parent remains unresolved without pickup. A successful child method can thus
remain attractive even as parent H reaches full breadth. This is a concrete next
diagnostic, not proof that one coefficient alone causes the whole trajectory.
No rest rule, H rule, initial heading or food position was tuned after the result
to force success. The parent-H gate is not the origin of the repeated-rest pattern,
which also occurs with it disabled.

Call times off55.082/on39.808 seconds, fixed order and compilation caveat above.
No full suite or cloud run was performed; this is a finite scene experiment.
