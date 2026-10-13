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

No dropped items were required by this natural scenario: the restored cargo branch
still needs a dedicated nonempty transfer test. Mode/geometry rejection and old
target release need explicit fault scenarios before checkpoint acceptance is full.
Static crossing clock uses world offset; local body/learning observations use new
cohort local time. Per-run diagnostic hazard counters start fresh.

This is environmental cohort transfer, not arbitrary process resume or same-agent
checkpointing. Python shared stock has no native counterpart yet (native stores
are private). Full LW migration and final30-day all-feature acceptance remain open.
