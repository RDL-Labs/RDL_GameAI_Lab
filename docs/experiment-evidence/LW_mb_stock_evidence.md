# Adopted M_B movement-field comparison with persistent resources

Baseline 4e648fb. Two real lightweight World runs, same seed 20260928, sparse geometry, three steady agents, skyline subrays, timed harvest, confirmed unloading, 30 days without return-count termination. The only paired intervention is `--mb-field-mode disabled|enabled`.

Unlike the earlier endless-first-patch run, these runs start with finite stock so existing observation-complete learning can form a model. No fabricated observations or pretrained model are injected. `--inexhaustible-after-model` switches remaining stocks to inexhaustible on first actual model adoption; already depleted patches remain empty. This is experimenter control, not a learned replenishment prediction or agent input. Both arms switched at 76.75 seconds (day 2), for C, with identical stock [12,12,12,7,12,12,0,12] and model `gameai-reconstructed-mb:1c5071f34315e46a:v1`. The transition record preserves the full existing three-formation/two-validation admission and model.

Both arms have M_B available for interpretation. Disabled suppresses only its movement-field contribution, not model adoption or all cognition. Steady profile remains fixed. This tests use of the adopted harvest relation, not learning a route.

## Results

| C day | Disabled movement / pickups | Enabled movement / pickups |
| --- | --- | --- |
| 1 | 36 / 12 | 36 / 12 |
| 2 | 49 / 12 | 49 / 12 |
| 3 | 52 / 19 | 50 / 19 |
| 4 | 19 / 33 | 16 / 35 |
| 5 | 0 / 24 | 0 / 24 |
| 6 | 0 / 20 | 0 / 18 |
| 7–30 | 0 / 0 | 0 / 0 |

Enabled applied the field on 34 decisions; disabled recorded 36 counterfactual opportunities. Counts after divergence are not matched observations. First actual action difference at 153.75 seconds: disabled move 1, enabled turn -45, with exactly equal observation packets. There are 16 differing action tuples among shared observation IDs, but later packets can differ because trajectories diverged.

Both completed 30 days with 120 pickups, only 2 returned batches (24 units), and 96 still carried by C. C retained 108 learning records and an adopted model; A/B had no pickups or models. Neither arm returned cargo after day 2, so the retained actual-carrying limit eventually stopped further harvesting/exploration. This is distinct from the fixed lifetime-count bug. No capacity bypass or teleport was added to force progress.

Conclusion: an actually adopted M_B influenced the movement field and changed an action under identical observed input. Shorter movement did not establish improved return, delivery, or exploration efficiency. The next constraint is reaching home with cargo; route learning itself is not established.

## Reproduction and evidence

```powershell
python -m integrations.lightweight.timed_harvest --days 30 --skyline-subrays --no-return-target --inexhaustible-after-model --mb-field-mode disabled --output integrations/lightweight/output/mb_stock_disabled.jsonl
python -m integrations.lightweight.timed_harvest --days 30 --skyline-subrays --no-return-target --inexhaustible-after-model --mb-field-mode enabled --output integrations/lightweight/output/mb_stock_enabled.jsonl
```

Both exited 0. Saved `lightweight_mb_stock_disabled.jsonl.gz`, `lightweight_mb_stock_enabled.jsonl.gz`, and `lightweight_mb_stock_comparison.json` include source hashes, actual transition admissions, full daily coordinate paths and summaries. Timed-harvest tests 5 PASS. Model-field regression results recorded separately below. Full suite and Luanti not rerun.
`test_model_movement_field.py`: 11 PASS; focused total 16 PASS.
