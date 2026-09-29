# Lightweight planar exploration World

Run from the repository root:

```powershell
python -m integrations.lightweight.world --days 3 --output integrations/lightweight/output/run.jsonl
```

Optional `--seed` (default 20260928), `--mode enabled|disabled` (default enabled), days 1–30. Each run is a fresh World. No Luanti, browser, HTTP or wall-clock sleeps are required. Output overwrites the explicitly named file.

The JSONL contains experimenter-only World truth; never feed its manifest/body coordinates to agents. Existing Runtime receives only generated packets and body results. p5 playback will be added in LW-2. See the LW-1 contract and evidence under docs.
