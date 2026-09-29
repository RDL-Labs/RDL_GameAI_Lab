# LW-1 three-day evidence

Implemented from plan baseline `3532f98`. Python World and unchanged ReturnCampaign run in one process with virtual time.

- Seed 20260928, three agents, eight resource patches of twelve units, three 64-second virtual days.
- 768 observations per agent; 2,304 observation/action/result rows total.
- Wall elapsed 2.372 seconds for this single run (includes incremental log writes). Not a general speed guarantee or a Luanti-equivalent benchmark.
- Pickups 0, returns 0, learned records 0, adopted models 0. Stop: time_limit. No learning improvement claim.
- Bodies changed: A 51 revisions, B 50, C 1. Limited progress and stopping are retained as results, not corrected by resource hints.
- Full increment log: `tests/fixtures/lightweight_world_three_days.jsonl.gz` (240,019 bytes). Summary contains source/log SHA-256.
- Dedicated tests: six PASS, including two one-day runs with identical records except wall elapsed.
- Existing ReturnCampaign regression: four PASS.
- Full repository suite and Luanti were not rerun; existing Runtime files are unchanged.

LW-0/1 finite connection is complete. LW-2 p5 replay is next; thirty-day/model-field comparison and goal-H connection remain unimplemented/unexecuted for this environment.
