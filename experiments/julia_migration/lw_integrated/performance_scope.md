# Performance evidence and comparison boundaries

This index is part of the LW migration deliverable. It does not establish a
whole-LW Python/Julia speed ratio.

| Measurement | Comparator | Supported conclusion |
|---|---|---|
| [A0](../all_loop/report.md), run38219271539 | identical finite9000-step Python/Julia workload | warmed Julia7.44–10.19x faster in that small body/resource loop; whole benchmark startup3.8s in both |
| [Compact recording](../compact_run/report.md), run38242086300 | detailed/compact Julia, same short fixture | execution21.2–30.3% lower, not full LW |
| [Latest integrated](latest_campaign_report.md), run38373033395 | two different seeds, same feature profile |3-day absolute time/RSS/allocation, not relative improvement |
| Latest30-day run38376126204 | frozen native replay plus second seed | RUNNING; no final measurements yet |

A0 excludes the later M_B/Sleep/social/landscape mechanisms. Its speed ratio must
not label the complete native living loop. Compact recording's JSON savings also
must not be interpreted as an equal decrease in simulation work.

Latest integrated first-call3-day measurements include compilation and exclude
serialization: seed04 675.0496s /1,168,994,304-byte peak RSS;
seed05 636.2103s /1,284,673,536-byte peak RSS. Allocations are about860.5/866.9GB
cumulative, not simultaneously held RAM. These costs show that Julia alone does
not eliminate allocation-heavy high-level processing. No hot-path attribution
has been measured for this exact feature composition, so no cause percentage is
claimed and no performance-only rewrite is introduced during acceptance.

Native summary.measurement contains call_seconds, allocated_bytes, gc_seconds,
process_peak_rss_bytes. Replay is warmed but peak RSS is cumulative within the
same process, so replay RSS is not an independent peak-memory trial. Compare
source/config/spec identities before comparing timings.

30-day capacity planning: simple10x scaling of the first3-day calls suggests
roughly106–113 minutes per call, plus a replay. This is a scheduling estimate,
not measured30-day time; history/behavior changes may alter scaling. The job cap
is360 minutes. A timeout is a failed duration gate, never evidence of completion.

A matched full Python-LW/Julia-LW throughput comparison is not currently available:
the native policy, one-second schedule and sensor adapters are functional ports,
not equal-operation backends. Report absolute integrated cost and the scoped
historical matched comparisons separately. Production switch remains conditional
on the completion audit, not a claimed speed advantage.
