# Lightweight planar exploration World

Run from the repository root:

```powershell
python -m integrations.lightweight.world --days 3 --output integrations/lightweight/output/run.jsonl
```

Optional `--seed` (default 20260928), `--mode enabled|disabled` (default enabled), days 1–30. Each run is a fresh World. No Luanti, browser, HTTP or wall-clock sleeps are required. Output overwrites the explicitly named file.

The JSONL contains experimenter-only World truth; never feed its manifest/body coordinates to agents. Existing Runtime receives only generated packets and body results. Read-only Canvas playback is available at `gui-p5/lightweight/`. Start `python gui-p5/serve.py --no-browser --port 8091` and open `http://127.0.0.1:8091/lightweight/?demo=1`. See the LW-1 contract and evidence under docs.


Paired audit:
```powershell
python -m integrations.lightweight.compare disabled.jsonl enabled.jsonl --output comparison.json
```
The saved 30-day gzip logs in tests/fixtures can be selected in the replay viewer. See LW_3_paired_campaign_evidence.md for the zero-harvest result.

Optional `--distant-mode patches` merges contiguous equal color/range ray intervals before the four-feature cap. Default `rays` preserves the original acquisition. This is not object recognition; overflow remains partial. See LW_3_distant_patches_evidence.md for the incomplete paired experiment.

`--layout sparse` keeps six of the dense layout objects while preserving all resource positions/stocks and initial agents. It changes visibility and collision, not Runtime decisions. Default remains dense.

`--approach-mode enabled` opts into the finite visible-food soft-repulsion appraisal. Default disabled. Example: `python -m integrations.lightweight.world --days 30 --layout sparse --approach-mode enabled --output integrations/lightweight/output/approach.jsonl`.

Timed harvesting (opt-in, sparse layout + approach mode):
```powershell
python -m integrations.lightweight.timed_harvest --days 30 --output integrations/lightweight/output/work.jsonl
```
Uses lw-timed-harvest-v1 event records; the original viewer does not yet support this format.

Add `--skyline-subrays` to the timed_harvest command for three finite rays per skyline bin. This only changes skyline acquisition and records the option in the manifest.

Add `--inexhaustible` to timed_harvest to keep all resource patches available without depletion. Existing per-agent cumulative96 acquisition cap and three-return stop are unchanged.

Use `timed_harvest --no-return-target` to continue until the day limit even after three returned batches. This does not remove the Runtime cumulative acquisition cap; see LW_inexhaustible_evidence.md for the 30-day continuation result.

The timed-harvest adapter now uses confirmed unload receipts to free carried capacity. The 96-item limit applies to current holdings, while acquisition history persists. Other Runtime integrations retain their prior accounting. Thirty-day infinite-stock continuation: 1046 pickups / 30 returns; see the latest evidence section.

For an adopted-model comparison use `--inexhaustible-after-model --mb-field-mode enabled` (or `disabled`) with `--no-return-target --skyline-subrays`. This starts finite and freezes remaining stock on actual adoption. See `docs/experiment-evidence/LW_mb_stock_evidence.md`; field application changed actions, but did not improve returns.

Timed-harvest return now keeps the home purpose while searching observed landmarks after home loss. Search/homing switches share finite daily budgets; night still ends movement. See `LW_home_search_evidence.md`: actual reacquisition occurred, but deliveries did not improve.

Unresolved return now carries overnight in timed harvest: next-day exploration time is allocated to home search, with cargo/history retained. Night remains stationary. See `LW_overnight_home_evidence.md`; 30-day daily resumption passed, but return remained unresolved and repeated paths persisted.
`--goal-difference-mode enabled` enables the local home-goal residual/method experiment; default disabled. See docs/experiment-evidence/LW_goal_difference_evidence.md for the supplied comparison hypothesis, Core boundary, and paired 30-day outcome (24 vs 67 delivered).
