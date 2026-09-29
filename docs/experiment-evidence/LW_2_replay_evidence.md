# LW-2 read-only replay

Baseline a131431. Added `gui-p5/lightweight/` alongside the existing p5 workbench. This separate viewer uses native Canvas, with no new CDN or library dependency; it does not modify Runtime or simulation.

Open `http://127.0.0.1:8091/lightweight/?demo=1` after running `python gui-p5/serve.py --no-browser --port 8091`. An identical copy of the existing three-day compressed fixture is bundled. Local JSONL and gzip files can also be selected.

Controls: play/pause, one observation slot, reset, seek, 1/4/16/64x speed, agent and view selection. Each slot groups all three agents. World view shows post-operation bodies, trails and experimenter stock. Agent view uses only the selected current packet and its command/result; skyline distance is schematic by range band, not exact distance. No true World coordinates are projected into that view. Logs are not mutated or sent to Runtime.

Incomplete final JSON lines and incomplete population tails are displayed as incomplete; corrupt interior rows are rejected. No summary means no completion claim. The viewer is intended for finite trusted experiment logs, not arbitrary schemas or unbounded streaming.

Validation: Node syntax checks; `node tests/test_lightweight_replay.cjs` PASS, covering fixture parsing, 768 slots, missing/truncated summary, corrupt rows, agent allowlist and input immutability. Headless Edge loaded the demo and rendered the full World, time controls and decision details (visual screenshot inspected). Interactive computer-use connection failed twice, so real click/drag and all control combinations were not browser-automated. No World rerun or full repository tests were needed for this read-only addition.

Goal H, canonical Sleep and thirty-day comparisons remain separate future work. Existing three-day fixture still has zero harvest/returns/models.
