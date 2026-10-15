# Parent return purpose across load-changing methods

Implementation `42e37e2`; [Actions 38341025882](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38341025882)
completed on Ubuntu24.04 / Julia1.13.1. 64 assertions passed (16 safety,
17 cargo,4 method semantics,9 purpose lifetime,6 controlled living checks,
12 integration invariants). Repository-wide CI was not rerun as part of this claim.

## Contract

The existing home BasicLoop keeps its H and method selection. An agent-local
purpose lifetime now records active/start/entry/completion state. Load six or the
return/night phase starts return. Subsequent load reduction, losing sight of home,
and crossing midnight do not cancel an unfinished return. Observing home within
the existing 1.25 radius with empty inventory completes it. The scheduled home
rest policy still applies after completion. This accepts empty-handed home arrival
as completion; it is not a claim that all original food was delivered.

Safety/social/eating/rest priorities remain before movement. These can interrupt
execution without deleting the parent purpose. Methods remain reselectable through
the existing home loop. No recovery prohibition or forced climb sequence was added.
This is a finite local purpose-lifetime fix, not canonical M_B reconstruction or a
general rule for abandoning high-level goals through H/theta. Such abandonment
remains outside this increment. State appears in day-boundary and final records.

## Same controlled World: before and after

| Event | Before | After |
|---|---:|---:|
| Drops | 4291 | 1 |
| Recoveries | 4290 (A) | 1 (B) |
| First A loaded climb | 8641 seconds | 61 seconds |
| A first deposit | after return phase | 62 seconds |
| Final stocks A/B/C | 5/6/6 | 11/4/3 |
| Remaining ground | 1 | 0 |

At 60 seconds A drops one; at 61 it climbs with load five; at 62 it deposits.
B recovers the abandoned unit at 64 seconds. C also attempts recovery at 64 but
finds it unavailable. Thus cross-individual recovery now occurs in the common
living loop, not only the transfer unit test. Initial inventory provenance is null;
this does not demonstrate transfer of a learned acquisition record in this run.

All 18 food units end in private stocks; no food is consumed or replenished and
none is carried. All three Sleep cycles complete. After return completion A resumes
ordinary exploration; later behavior is not held permanently in return mode.

## Native three-day regression

Seed20261005, renewable food, climbing/low-obstacles on, dropping off/on. Each has
155520 operations, stocks101/30/29, zero carried, nine completed Sleep cycles:
100 initial +96 added =30 ground +160 stored +6 consumed. Neither chooses a drop.
Both result files match their corresponding prior run38339954972 after recursively
removing the added `return_purpose` diagnostics. Food ledgers were independently
recomputed from downloaded summaries. No efficiency or speed generalization is made.


## Route attribution correction (2026-10-13)

`f7006e5` freezes the selected parent family into each plan and uses it for
route-result recording. Previously selection retained the return purpose after
a drop, but route recording recomputed the family from current load and phase,
mislabeling below-six-load daytime return movement as food exploration.

[Run 38352577186](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38352577186)
passed 71 assertions, including the controlled first drop-to-deposit interval:
every transition retains home purpose and no pickup/recover intervenes. Ordinary
three-day drop on/off and one-day controlled runs conserve resources. This does
not implement deferred multi-unit cargo-loss versus detour planning.
