# LW time-based return and skyline subrays

Baseline705fb23. Existing timed harvest continues exploring after acquisition and enters return at32s, night at56s of each64s virtual day. No immediate-return threshold or new navigation rule added.

## Failure diagnosis

In the previous run C held12 units at(-14.435,-9.435), yaw -90 at return start. Tower distance22.635, bearing39.622 degrees, apparent half-width2.532 degrees. A direct experimenter diagnostic ray hit the tower at0/15-degree elevation, while15-degree sample rays missed it. Four90-degree scans preserved the angular sampling gap. Tower coordinates were used only for this audit, never as navigation input.

## Opt-in acquisition change

`--skyline-subrays` samples each skyline angle at offsets -5/0/+5 degrees, clipped to the existing frontal sector. Within each angular bin the nearest visible hit is retained. Output remains at most39 features with the same coarse intervals, elevations and range bands. Height/occlusion/range checks remain. This is a changed finite acquisition plan, not proof of complete scene visibility or guaranteed tower detection. Mixed surfaces in a bin remain coarse. Horizontal landmark, distant and local channels are unchanged. Manifest records skyline_subrays; default false preserves the original sampler. Return policy never sees World position.

## Results

Three-day run:43 pickups, two returns by C on days1 and2, twelve units each. C had31 learning records and an adopted model. Thirty-day run:60 pickups, two returns/24 verified units,48 C learning records, one adopted M_B first observed at76.75s (day2). Run ended at time_limit, not three-return target. A/B models remained absent. Thirty-day elapsed23.395s; no general speed guarantee.

Every returned acquisition operation was checked for unique successful pickup, and the night-wait body's position was within the existing base audit radius10. Total stock consumption equals60 successes. Automatic unloading is existing World audit/accounting, not a new learned deposit action.

The changed observations and resulting trajectories can change learning opportunities. No model-field-disabled control was run here, so return/harvest gains are not attributed solely to learning. Learned influence on actions requires a separate paired comparison.

Saved `tests/fixtures/lightweight_return_subrays30.jsonl.gz` and `_audit.json` include source hashes, final summary, model timing and unique returned-unit audit. Uses timed-harvest event format; existing viewer support remains pending.

Tests: two new skyline tests PASS (sampling gap, other channels unchanged, bound, occlusion), four timed-harvest tests PASS. A bundled lightweight-suite invocation did not provide a successful summary, so no new full-suite PASS claim. Full repo/Luanti not run. An initial Python3.11 thirty-day process ended without summary; only later completed Python3.14 runs supply the results above.

Next observation: why the third return remains unmet and whether adopted M_B contributes, without requiring all agents to succeed or forcing home coordinates.
