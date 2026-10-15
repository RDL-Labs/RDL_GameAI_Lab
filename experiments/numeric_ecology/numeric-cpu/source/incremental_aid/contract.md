# Incremental aid: first behavioral-fidelity experiment

Policy: [behavioral fidelity](../../../docs/design/RDL_Julia_Behavioral_Fidelity_Policy.md).
Baseline cd65ce5. Experimental opt-in only; existing Python and default A2 API remain.

One owner holds LiveAid. pressure_update! mutates the same AidPressure and returns
it as a live view; retaining this return does not retain an earlier version.
pressure_snapshot explicitly deep-copies independently writable evidence/state.
Only snapshot has the former ownership guarantee. No forgetting, new H rule,
precision change or new canonical authority. Full accepted history is still kept.

In the opt-in A2 caller, social ingest appends at most one record; pre/post count
and last ID identify its notice without scanning/hashing history. This is an
append-only producer contract, not a detector for in-place edits of old records.
Direct notification checks actor and keeps up to 192 immutable receipts. Identical
replay is a no-op; changed same-ID notice rejects. A different target/agent cannot
silently reuse a receipt. Overflow rejects, no eviction or permanent replay claim.
Current observations/contact gates are still evaluated when no notice arrives.

Old copy tests belong to the old API and remain unmodified. New tests protect
explicit snapshots, no cross-agent contamination, replay/conflict, experience
dependent target choice (including swapped targets), unresolved pressure,
unexecuted versus unanswered requests, and current contact/food conservation.
Two short A2 fixture conditions exercise movement/social/Sleep. Old trace equality
is recorded diagnostically; divergence alone does not reject the new design.

Measure old and new pressure updates in the same job at 3/16/64 prior records,
zero/one new evidence, 30 warm samples, evals=1, 2-second cap. Include append-count
notification, notice construction/validation, receipt and evidence updates in the
new timing. Fixture reset is BenchmarkTools setup, outside timing: it restores the
same prior state each sample, not a copy required by the runtime update API.
Measure snapshot alone and update+snapshot separately. A2 diagnostic traces still
snapshot every actor-step; its social ingest still copies social records. No whole
loop speed or RSS reduction claim from this local measurement.

Stop at candidate/adjust/reject/undecided plus evidence. Full-suite/long campaigns
and A0 timing reruns are not required for this isolated experiment.
