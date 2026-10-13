# Julia Lightweight World entry

This entry delegates to the existing native -> run_integrated -> lw_day path;
it does not add another simulation loop. Migration completion review is ongoing.
The Python entry remains available and is not automatically replaced.

From repository root (Julia1.13.1):

```sh
julia --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/julia/setup.jl
julia --startup-file=no --project=experiments/julia_migration/julia integrations/lightweight_julia/run.jl outputs/lw-native --days 3 --seed 20261005
```

For the already accepted composed World, reuse a saved spec.json:

```sh
julia --startup-file=no --project=experiments/julia_migration/julia integrations/lightweight_julia/run.jl outputs/lw-replay --spec path/to/spec.json
```

Frozen input controls the configuration; other CLI configuration flags do not
override it. Preserve spec.json,manifest.json,result.json,summary.json together.
The default CLI is a smaller configuration, not the full accepted30-day matrix.
The documented full configuration is in lw_integrated/long_run_checks.jl.
Do not enable selection trails and bundle credit simultaneously.

Optional `--goal-switch-threshold 1..30` and
--lateral-side off|left|right affect selection. Old specs omit them and retain
threshold2 and no handedness. Set JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1
for comparison with saved performance runs. Peak RSS and cumulative allocation
are different measurements. No Python process is needed for simulation.

See docs/design/RDL_Julia_LW_Completion_Audit.md for remaining release gates and
experiments/julia_migration/lw_integrated/optimized_long_report.md for30-day
performance and replay evidence. Native geometry, action cadence, local schemas
and method vocabulary are adaptations; canonical T1 is not claimed.
