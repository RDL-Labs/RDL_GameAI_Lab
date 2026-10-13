# Elevated observation and native home search

Source9e966c6; reference integrations/lightweight/world.py::cast/packet,
runtime/landmark_day_cycle.py and runtime/local_return.py.

--skyline off preserves the earlier native local-home sensor. rays/subrays samples
13 horizontal sectors at elevations0/15/30 within48 units. Subrays checks-5/0/+5
inside each sector. Each sector reports its nearest height-intersecting feature;
output stays within39 features, with color, azimuth interval, elevation and coarse
range band. World coordinates, true object IDs and exact range are not emitted.
A clear ray with no feature is a complete scheduled acquisition, not unavailable.

At the first observation, one unique near elevated color can become the individual's
home appearance memory. An absent or ambiguous first observation creates no memory;
later unrelated landmarks do not silently become home. Later one contiguous matching
appearance produces a currently feasible home-search method. Multiple patches,
incomplete coverage, absent memory and body-infeasible directions produce none.
The source observation is retained. Matching appearance is not identity certainty.

In this opt-in mode the direct local-home observation range is6, not60. The World
still validates actual deposit at the existing native home location. Skyline
approach is only movement progress; it cannot resolve home completion. The existing
return parent, social/night priorities, route candidates and method selection own
all operations. The existing native geometry places home at[0,4]; Python's dock
adapter uses[0,6]. This change does not silently relocate the native World.

The direct local-home sensor still reports native relative distance within6, rather
than Python's angle/in-reach-only packet. Horizontal exploration remains its existing
fan. This is the elevated home-search migration, not full visual parity, new sight
at night, or general recognition. Latest-feature thirty-day acceptance is pending.

Actions38366944659 completed:57 assertions PASS. Three-day seed20261005
home-skyline selections: rays A365/B93/C518(total976), subrays A1317/B448/C302
(total2067). All nine Sleeps completed in each arm. Food balances:
off100+107=ground72+private/carried129+consumed6;
rays100+96=54+136+6; subrays100+84=36+142+6.
Frozen subrays replay is byte-identical. Saved balances and selection counts were
independently rechecked. Supply differs, so this is not a food-efficiency claim.
Call seconds were38.10(off, first compilation),40.27(rays),68.12(subrays),72.43
(subrays replay); different behavior and first compilation prevent a language speed
comparison. Main sampling and subray sampling have a visible cost.
