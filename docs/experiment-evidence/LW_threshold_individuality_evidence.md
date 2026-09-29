# Fixed switching threshold across three World seeds

Baseline dd684ac. Added `--goal-switch-threshold` (integer1–30, default2) and `--seed` (World layout seed) to timed harvesting. Each agent owns its fixed threshold used by its separate Home/Food goal contracts. Neither E nor H magnitude/decay changes. No NERV/SOC parameter is silently reused; this remains the local method-review threshold, not canonical theta/T1.

Predeclared grid: World seeds20260928/20260929/20260930 × thresholds1/2/4, each30days, A/B/C (9 World runs,27 agent runs). Each run assigns the same threshold to all three agents; compare the same agent/starting role across separate runs. This is not a mixed-personality population experiment. Shared-resource effects may mediate post-divergence outcomes; experiences are not assumed identical after actions diverge.

All other switches: sparse World, skyline subrays, actual timed harvest/unload, both goal method controls enabled, adopted harvest field enabled, finite stock until actual adoption then inexhaustible remaining stock, no return-count stop. Controller choice seed remains20260928 in every run; only World geometry seed varies between groups. Within each group initial manifests match exactly excluding threshold (audited). Geometry and initial resource positions vary between groups. Thus this is deterministic scenario dependence, not an estimated real-world luck probability.

## Results (population totals)

| World seed | Threshold | Acquired | Delivered | Batches | Movement | Food rescans |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 20260928 | 1 | 43 | 43 | 3 | 269 | 212 |
| 20260928 | 2 | 67 | 67 | 4 | 432 | 196 |
| 20260928 | 4 | 57 | 43 | 3 | 497 | 104 |
| 20260929 | 1 | 208 | 144 | 5 | 365 | 0 |
| 20260929 | 2 | 208 | 144 | 5 | 365 | 0 |
| 20260929 | 4 | 208 | 144 | 5 | 365 | 0 |
| 20260930 | 1 | 0 | 0 | 0 | 58 | 112 |
| 20260930 | 2 | 0 | 0 | 0 | 58 | 112 |
| 20260930 | 4 | 0 | 0 | 0 | 58 | 104 |

All completed the full1920 virtual seconds with exit0. Lower threshold is not uniformly better: threshold2 delivered most for the original seed; all three match delivery for the second seed; none harvested in the third. No universal optimum or statistically established population advantage is claimed. More movement alone is not efficiency. Rescan counts are real commanded turns; method activation counts in the JSON measure entry into the alternative method, not every turn or every phase switch.

Individual metrics in `tests/fixtures/lightweight_threshold_sweep/comparison.json` include movement, pickups, turns, alternative-method activations, rescans, final Home/Food H, delivery/carry counts and model refs, together with manifests, full terminal summaries and raw-log SHA256. Full raw/compressed logs are retained locally in ignored `integrations/lightweight/output/threshold_*` and `output/threshold_evidence`; the repository stores the compact audit, not nine duplicated large traces. `python -m integrations.lightweight.audit_threshold_sweep` regenerates the audit/archive and rejects incomplete runs.

Reproduce each grid member with:

```powershell
python -m integrations.lightweight.timed_harvest --days 30 --skyline-subrays --no-return-target --inexhaustible-after-model --mb-field-mode enabled --goal-difference-mode enabled --food-goal-mode enabled --seed 20260928 --goal-switch-threshold 1 --output integrations/lightweight/output/threshold_20260928_1.jsonl
```

Validation: generic goal tests6 PASS (same records/E/H at thresholds1/2/4, differing method selection; invalid runner thresholds reject), home search6 PASS, timed harvest5 PASS. Total17 PASS. Full suite/live Luanti not rerun. Fixed threshold variation is a behavioral tendency experiment, not a biological personality diagnosis.
