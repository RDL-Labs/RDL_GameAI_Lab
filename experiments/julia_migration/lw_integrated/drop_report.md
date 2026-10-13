# Julia LW drop and recovery execution

Code tested: `2d74fc7` (implementation `02318d3`).
[Actions 38339954972](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38339954972)
succeeded on Ubuntu 24.04 / Julia 1.13.1. 52 assertions passed: safety 16,
transfer identity/conservation 17, load and method semantics 4, living-loop drop 3,
and integrated invariants 12. This is not a repository-wide test result.

## Native three-day comparison

Seed 20261005, renewable food, low obstacles and climbing on; dropping off/on.
Both executed 155,520 operations. Actual drops/recoveries: zero. Both ended with
stocks A101/B30/C29, carried zero, and all nine Sleep cycles completed.
Food: 100 initial + 96 replenished = 30 ground + 160 stored + 6 consumed.
Drop candidates were registered but not chosen. Thus internal method dictionaries
differ; do not claim all output identical. Off-mode result exactly matches the
prior climbing-on artifact from run38338277709 after removing `dropped_cargo`.
No natural three-day drop benefit was demonstrated.

## Controlled one-day common-loop case

A starts with six units facing a height-0.4 obstacle and a visible home beyond it.
The same living loop executed 51,840 operations. A dropped 4,291 times and recovered
4,290 times; cross-individual recovery in this run was zero. The transfer unit test
separately verifies another individual can recover the original provenance.

The repetitive behavior is material: load six selects return; dropping to five
selects food exploration, which immediately recovers the nearby loose food and
restores load six. This repeats until the return-time phase at 8,640 seconds.
A then leaves one unit, climbs at 8,641 seconds with load five, and deposits five.
This is not a learned solution or successful purpose persistence. The next boundary
is maintaining the parent purpose across a load-changing method, not adding a
hidden rule forbidding recovery. No such behavioral patch was made in this run.

Final stocks A5/B6/C6; ground one, carried zero, consumption zero:
18 initial = 17 stored + 1 ground. All three Sleep cycles completed. A climbed once;
C climbed three times. Climb body correspondence mismatches were zero.

## Interpretation

Physical drop, recovery, conservation and provenance work in the common loop.
The means sequence remains behaviorally incomplete: immediate recovery undoes the
load reduction. Retained transfer records are bounded to 32; aggregate counts are
separate. The run does not validate emergency dropping, ownership negotiations,
or long-term cargo storage. Execution times include differing compilation states
and are not a performance comparison. Downloaded summaries were independently
checked for final food conservation; previous off-mode output was compared locally.
