# Compact recording: short-loop result

Verdict: **adoption candidate for the opt-in Julia experimental path**.
Run [38242086300](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38242086300),
code `2530915dd185a388878a5ee8e22df4dbd4ce82b8`, Ubuntu24.04 / Julia1.13.1,
single thread, human_scale_v1. Baseline implementation 9ccf86c.

## Change and lost information

`moving_scenario(...; incremental=true, recording=:compact)` omits per-step
full state snapshots. It saves per-agent action counts and transitions of
action/target/direction/food/status (also at day boundaries), with existing
night and terminal records. No pressure snapshots are taken on daytime steps.
Detailed recording remains the default with its historical output.
Compact cannot reconstruct all daytime observations, candidates, H or body
trajectories. Memory, H, decision cadence and World rules were not changed.

## Cost

Two fixtures, each 3 finite days × 90 ticks × 3 agents (810 daytime operations),
plus 2,880 rest updates per agent per night. Ten warmed samples per mode;
compilation excluded. Scenario execution includes fresh World creation,
decisions, social ingest, nights, recording, resource checks and duplicate
operation audits. JSON serialization is separate; disk/upload are not timed.

| Fixture | Execution detailed → compact | Cumulative allocation bytes | JSON bytes | JSON serialization |
|---|---:|---:|---:|---:|
| enabled | 104.194 → 72.591 ms | 62,134,136 → 43,130,528 | 3,695,822 → 19,365 | 206.895 → 0.988 ms |
| obstacle | 85.344 → 67.266 ms | 54,257,056 → 42,034,856 | 2,792,263 → 15,539 | 159.847 → 0.857 ms |

Execution fell 30.3% / 21.2%, allocation 30.6% / 22.5%, JSON size 99.5% / 99.4%.
Single-job finite measurements, not full LW speedups. Allocation is not retained
memory or peak RSS. Serialization medians are not a measured end-to-end sum.
Social ingest copies, operation/result history and audit copies remain.

## Validation

13 assertions PASS: invalid mode rejected; no detailed rows; all actions counted;
food total 60; all nights complete Sleep; transition count below step count;
final-state mutation does not alter earlier nights. Both modes retain existing
operation replay and per-tick resource audits. Compact checks each request
against currently observed food holders during execution.

Compact saved 44 / 39 transitions. Night/terminal states, requests, resource
endpoints and action counts agreed as diagnostics. Full action sequence equality
was not asserted. Earlier incremental behavioral tests remain unchanged but were
not rerun. No full suite, A0, long campaign or Python comparison rerun.

First run 38241912766 stopped after six passes: diagnostic helper parsed a night
array as a dictionary. Corrected array/scalar handling; no behavior or threshold
change. Successful artifact `julia-compact-run` contains raw timing samples,
stdout/stderr, specs and source hashes. Full daytime traces are not uploaded.
ZIP SHA256: `f5a8a048cecc6a0c97fa569fb109092098eeba70292b6be93ec9dde001aebe93`.

Next investigate social ingest or audit costs independently. The preceding
133× incremental-update microbenchmark is not a whole-loop speedup.
