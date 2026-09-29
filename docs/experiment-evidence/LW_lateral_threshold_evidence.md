# Handedness × goal switching threshold × World seed

Baseline aef92dc. Predeclared grid: left/right × local goal method-review threshold1/2/4 × World seeds20260928/20260929/20260930. Each condition is an independent30-day World with A/B/C. All three agents in a run receive the same fixed threshold and side; the matched role across runs isolates configuration from initial-position differences. This is18 World runs /54 agent runs, not a mixed-personality population test. No neutral individual profile is offered. Unspecified side retains the previous no-contribution control for older commands.

## Composition boundary

`runtime.composed_lateral_bias.apply` receives the already composed current terrain: physical/Food/obstacle + adopted-model field + approach appraisal. It preserves every existing term/provenance and adds only `lateral_cost`. It does not call the original terrain calculator again and therefore cannot drop the learned term. Complete terrain, both mirrored directions scored, no forward minimum, a mirrored minimum of the current appraised field, and per-component/total differences<=0.10 are required. Model-field-cost difference is checked too, preventing a clear model preference from being overridden. Contribution magnitude0.05 is fixed. Directions blocked/unknown stay excluded.

Steering v2 runs after this contribution and retains authority over heading persistence/reversal prevention. Pickup/body/return/night priority remains existing behavior. Lateral tendency affects this Food locomotion terrain only; it is not used to bias landmark choice, home search, rescan rotation or every body turn. The original separate Luanti lateral-bias mode and its old fixtures are unchanged. No tie-break random perturbation was added.

The experiment uses actual timed harvest, confirmed unloading, overnight home purpose, both goal residual controls enabled, and model field enabled; remaining stock becomes inexhaustible only after actual model adoption. Within each World seed all initial manifests must match excluding side/threshold. Controller seed remains20260928. Post-divergence experience can differ; threshold is not treated as a change to recorded E itself. Threshold is local method review, not automatic canonical theta/T1.

## Reproduction

```powershell
python -m integrations.lightweight.timed_harvest --days 30 --skyline-subrays --no-return-target --inexhaustible-after-model --mb-field-mode enabled --goal-difference-mode enabled --food-goal-mode enabled --seed 20260928 --goal-switch-threshold 1 --lateral-side left --output integrations/lightweight/output/lateral_20260928_1_left.jsonl
```

Use each declared grid member. `python -m integrations.lightweight.audit_lateral_sweep` audits completion, initial conditions, per-agent metrics, applied lateral traces and action sequence hashes. Compact evidence is committed; raw logs are retained in ignored local output paths. Identical action hashes compare agent/time/kind/amount/target across full traces, rather than inferring equality from aggregate yields.

Validation: composed lateral3 PASS (mirror response, preserved model/approach terms, no input mutation, forward/partial/blocked/component exclusions, neutral rejection); timed harvest5 PASS; home search6 PASS; goal contracts6 PASS; model movement field11 PASS. Total31 PASS. Full suite/live Luanti not rerun.


## Completed result

All18 runs completed1920 virtual seconds with exit0. Every left/right pair (nine pairs) has an identical complete action sequence hash. Delivery totals therefore match on both sides:

| World seed | Threshold1 | Threshold2 | Threshold4 |
| --- | ---: | ---: | ---: |
| 20260928 | 43 | 67 | 43 |
| 20260929 | 144 | 144 | 144 |
| 20260930 | 0 | 0 | 0 |

For20260929 each run had four applicable lateral decisions:24 total across six runs. Left side changed zero minima, right side changed four per run (12 total). The recorded first applicable example changes terrain minima from[-45] to[0] on the right, while both final commands are `move / observed_material_terrain_heading_held`. The perturbation can make forward best by raising a near-tied left cost; it does not force a right turn. Other two seeds have no eligible lateral application. Steering priorities were not weakened to manufacture an effect.

The earlier isolated Luanti lateral mode had an action branch; that does not guarantee one in this composed steering path. Here lateral contributions were real but no action/trajectory benefit or population role differentiation was established. Threshold-dependent delivery differences persist as in the prior sweep. These finite deterministic results neither show that handedness never matters nor establish an optimal threshold.

Artifacts: `tests/fixtures/lightweight_lateral_threshold_comparison.json` stores all18 manifests, SHA256 raw-log digests, terminal summaries, per-agent metrics, application/minimum-change counts, first applied observation/command/trace, and pairwise action-hash comparisons. Full logs stay local under `integrations/lightweight/output/lateral_*.jsonl`. An initial audit invoked during ongoing runs rejected an incomplete file; the final audit ran on completed logs and exited0. No incomplete simulation was counted as success.
