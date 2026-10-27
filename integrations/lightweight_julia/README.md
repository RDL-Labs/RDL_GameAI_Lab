# Julia Lightweight World entry

This entry delegates to the existing native -> run_integrated -> lw_day path;
it does not add another simulation loop. Julia is the primary repository entry
for standalone LW work; the declared major-function migration is complete.
Python remains available for reference and integrations outside that scope.
See [backend decision](../../docs/design/RDL_Julia_LW_Backend_Decision.md).
The root shortcut is `julia run.jl lw OUTPUT [options]` after dependency setup.

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

## Continuous movement direction

New runs through this stable entry default to `--continuous-descent on`.
Observed food/home targets contribute an attraction vector; nearby observed
obstacle hits contribute repulsion. For an ordinary selected `step_*` walk,
the resultant supplies a continuous heading, with collision and body checks.
Arrival, parent-goal completion, resource accounting and Sleep are unchanged.
This does not replace running, climbing, route methods or hidden-target search.
Use `--continuous-descent off` for a discrete-direction control.

Saved `--spec` files remain authoritative: missing `continuous_descent` means
legacy off. To adopt in a saved campaign, create a new spec with
`config.continuous_descent = "on"`; retain the original for comparison.

The easy-food (5,16) ten-day run completed in 212.26 seconds: each agent picked
up 28 units, deposited ten times and completed ten Sleeps. Shared stock was60;
daily continuity/conservation checks59 passed. This is a benign-world result,
not a general navigation guarantee. See
[descent report](../../experiments/julia_migration/lw_integrated/descent_report.md).

### 日末保存・再開

`--checkpoint-dir DIR` で日末の完全状態を保存し、`--resume-from DIR/day-005.jls` で6日目から再開できます。別の出力先を指定してください。最終日数以外の入力とJulia・ソースの版が一致する必要があります。
詳しい条件と岩囲い実験での利用は [チェックポイント仕様](../../experiments/rock_gate/checkpoint_report.md) を参照してください。
