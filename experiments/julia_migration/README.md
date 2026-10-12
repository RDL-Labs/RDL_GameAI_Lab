# Julia migration probes J0–J3 and standalone loops

[Independent narrower replacement B1f](lw_relearn/report.md): 30 assertions PASS.
Provided acquired-only schema passes native Sleep replacement/review tests.
Four-day living has only3/4/0 new attempts: no natural replacement formed.
Original evidence is not recycled; canonical reconstruction remains unported.

[Later harvest review B1e](lw_review/report.md): 65 assertions PASS.
Frozen pickup predictions are compared with accepted results and next observations.
Three natural persistence counterexamples invalidate local model use; living continues.
Replacement learning and canonical reconstruction remain unported.

[Learned movement appraisal B1d](lw_field/report.md): 24 assertions PASS.
Sleep-formed local harvest models bias current feasible food movement candidates.
Three-day sparse scene:106 same-state selection changes, stock63->82 (one seed).
Canonical T1/general Sleep and later model invalidation remain unported.

[Harvest Sleep intake B1c](lw_harvest/report.md): 37 assertions PASS.
Actual pickup and subsequent observations feed a frozen three-formation/two-validation
night inspection. Local models persist and B uses one on day3 in the sparse scene.
No new action authority; canonical T1 and general cross-action Sleep remain unported.

[Observed landmarks and routes B1b](lw_landmarks/report.md): finite reconnection.
39 assertions PASS; two scenes, enabled/disabled, three continuous days each.
Current visual landmarks and actual delivery-supported color routes affect movement.
Full navigation and general harvest Sleep integration remain incomplete.

[Reusable goal/method loop B1a](lw_loop/report.md): finite implementation,
66 assertions PASS, two continuous three-day scenes. Goal and method H separated;
unresolved-method reconsideration and private stock carry-over exercised.
Full learned landmark/route navigation and general Sleep remain unported.

[LW lifecycle reconnection B0](lw_day/report.md): two continuous one-day scenes,
three agents each, conservation and Sleep PASS. Provisional navigation ends in
lost-home scanning; not full LW reproduction. B1 must port goal/landmark recovery.

[Compact A2 recording](compact_run/report.md): finite adoption candidate.
Every-step snapshots omitted in opt-in mode; whole short-loop time reduced
21–30%, JSON size about 99.4–99.5%; 13 checks PASS. Not full LW adoption.

[New behavioral-fidelity policy](../../docs/design/RDL_Julia_Behavioral_Fidelity_Policy.md)
applies to new redesign experiments; earlier parity contracts remain historical.
[Incremental aid](incremental_aid/report.md) is an opt-in adoption candidate:
mutable updates, explicit snapshots, 40 behavioral/boundary checks. Equality is
diagnostic. Snapshot costs are measured separately; full LW adoption is not claimed.

[Cruise-cost diagnostic](typed_models/cruise_report.md): unchanged-history versus
one-new-record updates at 3/16/64 accepted records. Zero-new still scans all input
and allocates an independent state. Sixty ownership assertions pass. No copy-policy
change or full-loop speed claim.

[Typed goal/aid state](typed_models/report.md): GoalState and AidPressure preserve
A1/A2 parity, including overnight/final physical state. Twelve Julia-native
ownership/parity assertions pass. Paired local measurements show 1.03–1.25x speed
and lower allocated bytes; neither full-loop speed nor peak RSS is measured here.

Independent experiment; Python remains the only production backend.
[J0–J2 results](report.md): 1146 equivalent cases, three timing series,
roughly 17x warm 100-object kernel speed, substantial startup/RSS overhead.
[J3 results](j3/report.md): persistent shadow bridge matches 178,005 captured
queries, but total batch latency is 1.93–1.99x Python. This bridge is not adopted.
J4 and production adoption are not implemented.
The separately authorized [ALL-loop A0](all_loop/contract.md) tries an entirely
Julia-owned minimal loop. It is not a port of the complete LW integrated campaign:
M_B/E/H/theta, Sleep and social relation logic remain outside A0.
[A0 results](all_loop/report.md): 9,000 steps match; warm complete minimal loops
are 7.44–10.19x faster, but short process wall time is similar and Julia RSS is
roughly 24–25x. This is not an integrated LW speedup claim.
[A1 local model / Sleep / social parity](social_loop/report.md): five fixed-contact
three-day fixtures match Python, including goal/method H, accepted rest, social
expectation and next-day selection. A0 regression passes. General Sleep admission,
canonical T1 and integration into navigation remain unported; no A1 speed claim.
[A2 moving contact parity](moving_social/report.md): six three-day fixtures compose
A0 movement with A1 local aid and Sleep. All 4,860 daytime rows and nightly terminal
states match; A1/A0 regressions pass. Current contact gates social targets and execution.
Sleep adoption makes no action difference in these fixtures. This is not the full
LW exploration/return policy, continuous whole-day metabolism, or a speed benchmark.
Baseline: `52a94225484f7e1771c4b4c3703c3eb9eef39730`.
No runtime, World rules, H, rho, observation cadence or test expectations changed.

Run from repository root on Linux with Python 3.12.15 and Julia 1.13.1:

```sh
export PYTHONHASHSEED=0 RDL_LW_TIME_PROFILE=human_scale_v1 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
python -m experiments.julia_migration.python.export_fixture --maintenance
python -m experiments.julia_migration.python.profile_baseline outputs/julia_migration/run
julia --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/julia/setup.jl
julia --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/julia/test/runtests.jl
python -m experiments.julia_migration.python.measure outputs/julia_migration/run
```

The manual workflow automates this, records the resolved Project/Manifest and
restores them in a second empty Julia depot. Initial dependency installation is
separate from timing. The actual lockfile from the first run is checked in.
No JuliaCall or production dependency is added. J3 is a separately authorized
shadow experiment: see [contract](j3/contract.md) and the manual
`julia-migration-j3.yml` workflow. Stop after J3 review.

User plans: `contracts/plan.md` and `contracts/first_experiment.md` preserve the
provided draft, including future stages that are NOT authorized by this probe.
See `contracts/equivalence.md` for the preregistered input and timing boundaries.
