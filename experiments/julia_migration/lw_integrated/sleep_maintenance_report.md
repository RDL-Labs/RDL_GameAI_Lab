# Julia Sleep usage, dormancy and reactivation

Code `180eca7`; [run38346896356](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38346896356)
passed41 assertions (safety16, maintenance14, integration8, living boundaries3).

## Finite adaptation

`--sleep-maintenance on` requires general-sleep apply. It ports the lifecycle
principle of runtime/bundle_sleep.py onto Julia's current individual action records,
not full conjunction bundles. An opportunity means a retained record contributed
to a currently feasible candidate. A use requires a changed choice and execution
of the chosen walk/scan (performed or blocked). This is usage, not correctness or
successful goal achievement. Same-operation use receipt is idempotent locally.

Completed Sleep reviews only previously formed active records. Used records reset
idle count. Unused records become dormant after two idle Sleeps if opportunities
exist at review, otherwise three. No deletion or claim of falsehood follows.
New admissions do not age in their own formation Sleep. Duplicate day review has
no effect. Active capacity32, total source capacity192. New excess admissions are
dormant; reactivation respects capacity. Deterministic source-id order allocates
slots; this is a finite implementation choice, not learned prioritization.

During exploration/return, matching observed context and recorded phase can wake
a dormant record. Missing context and night do not wake it. Repeated night review
or replay does not amplify support. These are per-record semantics; bundle formation,
parent credit, full body-context migration and arbitrary hierarchy remain gaps.

## Four-day native comparison

Seed20261005, renewable food, strata retention, general-sleep apply. Other optional
adapters off. Each207360 operations; all12 Sleep cycles complete.

| Individual | Total retained sources | Dormant at end | Wake events | Local Sleep choice changes |
|---|---:|---:|---:|---:|
| A |22|4|0|129|
| B |16|7|0|0|
| C |19|3|0|158|

The14 dormancy events occurred in actual living nights. No reactivation occurred
in this run; context/phase waking and active-capacity limits are local-test evidence
only. Final stocks A119/B6/C47, B carries4. Food ledger:
100+143=60 ground+172 stored+4 carried+7 consumed.
These quantities, application counts and choice-change counts equal the maintenance-
off comparison. No new behavioral benefit is claimed. The287 local choice changes
are the existing Sleep-model effect, not an incremental dormancy effect.

Downloaded summaries were checked for food conservation. Body/Sleep invariants
passed. Times include differing compilation states, not a speed comparison.
Normal Python CI for the earlier import fix (run38346180589) remains in progress
at report preparation, Godot job succeeded; do not infer full-suite success.
