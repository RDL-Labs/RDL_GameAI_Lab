# B0: LW lifecycle reconnection

Baseline 5007edc. This is the first continuous-day scaffold, **not LW parity or
full reproduction**. Stop performance-only work; reconnect living behavior.

## Inventory and plan

| LW subsystem | Julia current | Next boundary |
|---|---|---|
| World geometry / local food / collision | A0/A2 primitives | B0 imports sparse LW layout; simplified sensors |
| Body / energy | walk, rest, eat | B0 every simulated second; other actions remain unported |
| Day / return / personal stock | missing in A2 | B0 continuous exported LW calendar, observed beacon return, own deposit/retrieve |
| Social / local aid H | A1/A2 + mutable aid | reuse within B0; B refuses, C shares as existing fixture |
| Sleep / local social model | accepted rest, social expectation | B0 actual night results, no clock jump; no general harvest Sleep |
| Nested M_B exploration / route learning | missing | B1 port methods/goal pressure and observed landmarks, remove temporary navigator |
| Cross-action Sleep / adopted harvest field | missing | B2 reconnect after B1; demonstrate following-day influence |
| Hazards / rescue / ground wear / dynamic resolution | missing | subsequent isolated integrations |

Initial target is three agents, one full human_scale_v1 day (17,280 seconds).
Then extend to three days after the missing navigation/learning connection is
explicit. Do not label a longer simplified fixture as full LW reproduction.

## B0 semantics

Export World(seed=20261004, layout=sparse) geometry/resources and the existing
social_shared scene layout. Initial inventory 0/2/2 and reserve 30/90/90 are
controlled conditions, not claimed to be natural LW defaults. Resource stocks
are finite and shared; stored stock is private, consumed only after retrieval.

Julia owns observations, selection, body execution and learning. No Python step
callbacks, time jumps, teleports or daily artificial reserve subtraction.
One action/body update per second; simplified scan is 60 degrees with rest cost.
Pickup is one second rather than LW's 0.5s timed work. Nonmovement social/store
actions receive rest metabolism. These are declared approximations, not LW body
parity. Night starts at 11,520s; quiet rest begins at 14,400s. Rest may occur
outside camp. Need for food and social replies can interrupt it.

The home sensor is a **new provisional visible beacon**: 60-unit range, front
hemisphere (near contact exempt), planar line of sight. Controller receives only
relative forward/right/distance; execution checks physical home contact.
This is not the elevated skyline appearance matching in LW. If unseen, scan;
this scaffold does not yet have lost-home exploration. Return begins at scheduled
time or six carried items. Local food steering and those rules are temporary,
not learned route M_B. No claim of removal of LW's stagnation failures.

Ingest occurs when a social request is pending; mutable aid polls only new
accepted records. Existing finite 192-record capacity retained. Operation
identity uses second/actor; communication receipts retain duplicate protection.
No new adversarial replay test is claimed for pickup/storage.

Record phase/action/target/status transitions, action counts, final body,
position, inventory, private stock, accepted Sleep and social/aid state. Assert
food conservation every second, all 51,840 actions accounted, and night completion
in these fixtures. Sleep's harvest branch remains insufficient evidence.
Runtime elapsed includes initial compilation; not a performance comparison.
