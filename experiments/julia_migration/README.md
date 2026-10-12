# Julia migration probe J0–J3

Independent experiment; Python remains the only production backend.
[J0–J2 results](report.md): 1146 equivalent cases, three timing series,
roughly 17x warm 100-object kernel speed, substantial startup/RSS overhead.
[J3 results](j3/report.md): persistent shadow bridge matches 178,005 captured
queries, but total batch latency is 1.93–1.99x Python. This bridge is not adopted.
J4 and production adoption are not implemented.
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
