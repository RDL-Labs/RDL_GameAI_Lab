# Campaign history sharing: semantic replay and incomplete live run

Baseline: `66e1626`. Runtime change: share immutable completed night entries and initial home evidence internally; preserve independent public snapshots. No action, learning, observation, day budget, queue capacity or GC policy changes.

## Recorded-prefix comparison

`luanti_l15a_campaign_history_comparison.json` compares the same 69,887 received responses (34,943 observations). Every response and all six final public agent-state hashes match. This prefix excludes accepted requests whose replies World never received.

| Measurement | Before | After |
| --- | ---: | ---: |
| Observe total | 104.819 s | 61.748 s |
| Observe maximum | 1.614 s | 0.814 s |
| Generation-2 collections | 14 | 10 |
| Generation-2 maximum | 1.609 s | 1.015 s |
| A completed-night references | 64,064 | 64,064 |
| A distinct stored night entries | 64,064 | 22 |

The longest baseline observe contained a 1.609 s GC pause during decision storage. Timers are inclusive. The after-run maximum GC occurred outside observe; GC stalls remain. These are single measurements, not throughput guarantees. Extraction ran separately; full public snapshot hashing was outside measured replay.

## Actual Luanti run: NOT COMPLETE

`l15campaign-c67137f7a391`: six agents, 1x, 30-day limit, six returned batches, natural meadow, steady assignment, model field and harvest state enabled. It completed 29 days and stopped at 1,882,130,277 us (day 30) with `per-agent pending capacity`. No completion claim is made. The last periodic progress record, at day-30 entry, records **three returns**; it is not a final audited return count.

World work immediately before failure includes approximately 200–370 ms sampling steps. Maximum measured step work was 368,315 us. Another Python workload started during the run; it was left untouched. Thus reaching day 30 rather than the earlier day 23 cannot be attributed solely to this change.

World's monolithic JSON export did not finish within the launcher deadline (30*64 + 900 seconds from launch). The process was stopped by its launcher. No full World JSON or completed export diagnostics were produced. The runner consequently did not retain live Runtime GC timing. This is an evidence-export failure in addition to the pending-capacity stop, not a successful acceptance.

Before timeout, the actual Runtime endpoint was saved to a separate file (2,468,406,578 uncompressed bytes), subsequently compressed as `luanti_l15a_campaign_history_runtime.json.xz`. This read happened after simulation stopped and adds export-phase host load. `luanti_l15a_campaign_history_recovery.json` preserves before-export World diagnostics and last progress. The initial `luanti_l15a_campaign_history_world.json.xz` contains predeclared settings/source hashes only, with an empty runs list; it is **not** a completed World replay. Runtime alone cannot reconstruct missing World actions or validate full acceptance.

## Validation

- Full suite: 1,059 run, 1,008 PASS, 51 intentional skips (587.312 s).
- Two history-storage tests include failed sensory admission, retry, append isolation and caller snapshot isolation.
- After adding passive live GC instrumentation: four diagnostics tests PASS (three overlap the full suite; no claim that a 1,060-test full suite was run).
- Recorded-prefix response/state equivalence: PASS.
- Actual 30-day acceptance and complete World replay: NOT COMPLETE.

Next: preserve diagnostics on launcher failure and replace the monolithic full-history export with bounded/incremental evidence before repeating long runs. Investigate World sampling and pending growth separately from Runtime GC; do not enlarge agent budgets to mask them.
