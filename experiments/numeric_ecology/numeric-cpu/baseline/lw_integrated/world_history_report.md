# Native environmental cohort checkpoint

Source `276a595`, reference integrations/lightweight/cohort_world.py.
[Actions 38363602204](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38363602204):39 assertions PASS.
Existing native loop, no additional living engine.

world_checkpoint records resource positions/current stock, original replenishment
geometry, dropped-item provenance, ground state and dynamic territory/patrol pose,
mode,clock. scene.world_history restores it; mode/geometry/day mismatch is rejected.
World clocks advance across cohorts. A territorial target belonging to the departed
cohort is cleared and return-to-home begins. New agents have fresh policy/body and
inventory. Private carried/stored food departs with old agents; it is not silently
introduced as shared food. New cohort initial food accounting starts independently.
Original resource caps control replenishment; dropped sites are excluded.

One-day seed20261005 with mixed hazards,patches,wear,dropping enabled produced
52 ground food. Next cohort starts52+4 carried=56; first inherited morning adds44.
Final next balance56+44=ground60+private/carried37+consumed3.
Saved next/replay result.json independently verified byte-identical. Both loop
invariants and time/replenishment transfer tests passed.

No dropped items were required by the initial natural scenario. The follow-up
below covers nonempty cargo transfer and incompatible input rejection.
Static crossing clock uses world offset; local body/learning observations use new
cohort local time. Per-run diagnostic hazard counters start fresh.

This is environmental cohort transfer, not arbitrary process resume or same-agent
checkpointing. Python shared stock has no native counterpart yet (native stores
are private). Full LW migration and final30-day all-feature acceptance remain open.


## Follow-up: inherited cargo and input rejection

Source `bdbdc5c`, [Actions 38363996101](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38363996101): 57 assertions PASS.
The eight incompatible-input cases reject changed resource geometry, resource
mode mismatch, fractional/negative stock, invalid whole-day time, ground/hazard
clock mismatch and a resource site mislabelled as dropped cargo.

A dedicated fixture supplies three old-cohort loose-food units, zero resource
stock and no replenishment, using the same native living entry point. A recovers
one and B recovers two. All three retain `inherited/old_actor` provenance; no
old item is duplicated. Final food balance is 7 = ground 0 + private/carried 6
+ consumed 1. The departed territorial target is absent at the final endpoint.
This is a constructed transfer test, not spontaneous cargo production by the
preceding cohort. It does not establish a complete life cycle: this fixture's
Sleep endpoints remain pending.

The ordinary next-cohort run and frozen replay remain byte-identical, independently
checked from saved result files. Their balance is 56 + 44 = 60 + 37 + 3.
These checks close the listed cargo/target/mismatch test gaps, not arbitrary
checkpoint compatibility or same-agent resume. Latest-feature multi-seed thirty-day
acceptance and shared-stock semantics remain outstanding.
