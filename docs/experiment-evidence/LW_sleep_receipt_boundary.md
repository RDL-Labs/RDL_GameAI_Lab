# Sleep receipt boundary and two CI regressions

2026-10-12. Previous cloud one-day evidence at ce689777 has 2880 real one-second
wait results per agent but only 2879 seconds credited, pending Sleep. No new full
human-scale World run has yet verified the fix described here.

Body-mode LW now consumes each already accepted result immediately after
loop.result. A night wait with unchanged pose/revision credits its actual bounded
duration. Invalid night actions reset accumulation. Last processed completion
time prevents replay credit. Completion beyond the originating night is not
credited. No synthetic observation or additional action is generated. Original
observation evidence remains unchanged; consolidation time uses result time.
The subsequent observation does not credit the same result again. This also
occurs before day rollover or final campaign closure. Nonbody legacy behavior
remains on its existing observation-based path.

Tests cover the 2879+1 second terminal boundary without a next observation,
duplicate receipts while pending and completed, unaccepted results and failed
wait. The 19-test related suite passed, including live legacy three-day body
Sleep, rescue and event/full log nonintervention. Full suite is left to cloud CI.

## CI differences isolated

RescueWorld inherited ordinary_resistance=1.5 after 25b0fa2. Its fixed .15 reserve
fixture had originally used resistance=1. With load=1 the changed resistance
requires .165 reserve for walking, while its chooser's old feasibility check
uses .11. The dedicated original fixture now explicitly fixes resistance=1;
existing exhaustion expectations pass without changing integrated landscapes.
This does not add terrain-aware rescue choice for arbitrary resistance.

For the food_barrier fixture, only continuous_selection.review was replaced
with its pre-9ce3f5f implementation in an isolated local comparison:

| Selection implementation | Pickups | Returned | Carried | Return times (us) |
|---|---:|---:|---:|---|
| before turn/step commitment | 36 | 12 | 24 | 87250000 |
| current | 36 | 24 | 12 | 36000000, 37250000 |

Thus this is a verified behavioral consequence of the explicit movement fix,
not a duplicated pickup. The current live test expects 24 returned/12 carried;
saved historical replay expectations remain unchanged. Body continuity,
duplicate checks, nine completed Sleep cycles and source provenance still pass.
