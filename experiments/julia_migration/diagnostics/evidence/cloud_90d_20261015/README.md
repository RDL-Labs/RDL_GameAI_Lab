# Julia LW: cloud 90-day campaign

Completed 2026-10-15 09:48:09 JST. One continuous World, three agents,
seed 20261005. Exit code 0; existing campaign validation: **473 assertions
passed** (16 safety + 4 Sleep observation + 4 integrated + 449 daily checks).
All 90 days and 4,665,600 actor operations completed.

## Reproduction scope

Source: `5b09a58c3009f59044cc08d2a551f939a3fa7790`, whose simulation code
matches checkout `a1840954c49a25a2253643148fd70860f92fecfb` (the latter adds
diagnostic tools). Julia 1.13.1, JULIA_NUM_THREADS=1,
OPENBLAS_NUM_THREADS=1. The frozen search_review World uses riparian terrain,
mixed hazards, continuous descent, parent breadth on and repetition pressure off.
See `spec.json` for all settings.

This is an experimental extension beyond the original 30-day validation range.
`experiment.patch` records every change to the archived source: days 30 -> 90
in the saved spec, two duration validation ceilings 30 -> 90, matching usage
text, and read-only progress instrumentation. Behavior rules and coefficients
were not changed. The tracked application checkout was not modified.

From the repository root, with the pinned Julia available:

```sh
export JULIA_BIN=/absolute/path/to/julia-1.13.1/bin/julia
export JULIA_DEPOT_PATH=/absolute/path/to/writable/julia-depot
bash experiments/julia_migration/diagnostics/evidence/cloud_90d_20261015/reproduce.sh /absolute/path/to/new-output
```

The runner archives the exact source, applies the recorded patch, instantiates
its locked project, and runs `search_review_campaign.jl`, including its existing
end-of-run assertions. It refuses an existing output directory. It does not
resume a partially completed campaign or retry failures. Environment shutdown
can terminate even detached processes. Keep status, progress and error logs.
This archived run passed; the 90-day reproduction has not been run a second time.

## Behavior observed

| Agent | Pickups / deposit actions, total | Final reserve | Final food H / home H | Outcome |
|---|---:|---:|---:|---|
| A | 151 / 36 | 86.436 | 0 / 0 | All-rest days 57–70; later resumed activity. Day 90: 9 pickups, 2 deposits. |
| B | 194 / 45 | 89.625 | 0 / 17 | No all-rest day or zero-reserve day-end. Day 90: 3 pickups, 1 deposit. |
| C | 74 / 17 | 0 | 32 / 32 | All-rest days 63–90, with no position change. |

These counts are actions, not necessarily food units. `daily_agents.csv` gives
daily increments of cumulative action counters and day-end physical/goal state
for all 270 agent-days. It includes earlier interruptions omitted from the
short table (A also rested all day on days 52–54; C had earlier interruptions).
Day-end H does not describe within-day H or directly measure comparison cost.

C last retrieved food and ate on day 58; its return purpose then remained
active. On day 62 it exhausted reserve at (23.1365, 63.4134), approximately
61.90 m from home (0, 6), and remained there through day 90 with no food.
This is a return/supply failure, not a modeled death. On day 63's end B was
9.06 m from C; this does not prove visibility, transfer range or the minimum
distance during that day. No request/give/refuse event involving C is recorded
after day 62. Continuous position trajectories were not saved.

Food accounting: initial 124 + replenished 398 = ground 99 + shared 198 +
consumed 225, with final carried/personal stocks zero. Conservation and
overnight carryover passed, but those invariants do not establish successful
living or habituation for every agent. Activity loss is a possible contributor
to lower late-run processing cost; causality has not been profiled.

## Performance

- Runner wall time excluding setup: 30,437 s (8 h 27 min 17 s).
- Simulation call, compilation included: 30,278.896 s.
- Instrumented loop: 30,152.162 s. `daily_timing.csv` covers all 90 days.
- GC: 1,997.496 s, approximately 6.6% of simulation-call time.
- Cumulative allocated bytes: 2,669,987,673,008 (about 2.67 TB, **not RSS**).
- Process peak RSS: 1,713,446,912 bytes (about 1.60 GiB).
- Host reported Intel Xeon Platinum 8573C; see `run_metadata.json`.

The earlier interrupted 30-day run on an AMD EPYC 9V74 took 60.14 s for
day 1; this run took 513.04 s. At simulation second 141600 the measurements
were 495.09 versus 3819.85 s. Earlier-run peak RSS was 1.22 GiB versus
1.03 GiB here at that point. These are historical observations, not a
controlled hardware benchmark: allocation/copying, generated code, shared
host effects and hardware performance have not been separated. The earlier
run stopped without an exit record; its cause is unconfirmed.

## Preserved evidence

- `result.json.gz`, `summary.json.gz`: lossless full outputs, not samples.
- `spec.json`, `manifest.json`, `experiment.patch`: exact inputs and provenance.
- `progress.tsv.gz`, `memory.tsv.gz`: original progress and process samples.
- `validation.txt`, `setup.txt`, `status.txt`: original logs and exit status.
- `daily_agents.csv`, `daily_timing.csv`, `run_metadata.json`: derived summaries.
- `SHA256SUMS`: integrity hashes for the evidence and reproduction script.

Some original logs retain the original local output path for provenance.
It is not a required path for reproduction. `loop_complete` reports day 91
because the progress formula labels the terminal boundary one day past the
last day; completed duration is exactly 90 days.
