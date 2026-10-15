# Fixed territorial response and patrol in native LW

Code7bfb977. Python references territorial_hazard.TerritorialHazard and
patrol_hazard.PatrolHazard. --hazards territorial|mixed adds the existing fixed
World behavior; crossing/off remain available. Mixed contains territory+patrol.

Territory center(-20,-2),home(-20,-14),radius8,leash12; nearest entrant selected
with actor tie-break. Approach speed2,warning distance3,return when target leaves
or leash reached. Patrol speed1.5,90-degree turn every12s or upon collision.
Both use physical obstacle footprints and stop on collision. No attacks,damage,
learning predator or hidden territory notification is introduced.

World motion uses250ms substeps between native one-second actor steps. Agent
poses remain their last actual positions during those substeps. A current
relative feature is visible only inside current sensing radius/front/LOS. Actor
policy receives neither center/home nor World target/mode. World diagnostics keep
32 recent substeps and total mode counts. No additional simulation loop for life.

This ports World motion, not full Python multi-threat safety selection. Existing
Julia safety still selects against its nearest observed feature; minimax/method H
integration remains a separate gap and must be completed before full parity.

Validation includes a frozen Python60-second trajectory with entrant/leaving
transition,body positions and patrol turn behavior. Integrated three-day off/mixed
comparison includes running,metabolism,hunger and general Sleep/lifecycle.
Cloud run38350933083 passed753 assertions:726 trajectory/replay/clock,
16 existing safety,8 integrated invariants,3 live hazard checks.

Native seed20261005,three days,155520 actor operations per condition. Mixed World
mode substep counts:idle201542,approaching2784,warning469,returning2562.
Safety overrides A10547/B6753/C4801. These include repeated re-entry; they are not
distinct encounters or verified safe escapes. The policy has no hidden mode feed.

Mixed food ledger100+32=ground86+stock30+carried5+consumed11. Stocks A13/B10/C7.
Sleep completion A0/3,B1/3,C2/3,versus9/9 without hazards. This is an outcome, not a
failed conservation check or a guarantee that warnings alone caused every pending
cycle; individual night interruptions still need separate diagnosis if relevant.

No full-suite,30-day or performance claim. Body/food/Sleep interact with actual
World response. Full multi-threat method selection remains next.
