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
