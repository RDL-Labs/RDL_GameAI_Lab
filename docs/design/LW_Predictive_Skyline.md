# Predictive skyline observation (experimental)

2026-11-03. First connection of short-lived prediction to static distant visual observation. Enable scene.predictive_skyline=true (default false). This is a sensory approximation, not a fixed action or forced goal choice.

Only skyline ray casting is deferred. Horizontal landmarks, food availability, home observation, local obstacles, movement feasibility and physical collision remain current. Static world geometry is assumed; dynamic geometry must invalidate this mechanism before adoption.

The previous skyline is advanced by proprioceptive forward/right displacement and yaw. Mid/far bands use representative distances 16/36, not hidden object positions. These are approximate bearings; occlusion can change before the next fresh sample. Predicted output has coverage=predicted and original observed_us, and does not increase skyline observation counts or initialize home memory. Existing cue generation treats partial/predicted views as uncertain; skyline home direction can use the prediction without certifying arrival.

Refresh on fine rho, missing/nonconsecutive receipt, stationary/blocked movement, turn above 5 degrees, accumulated travel above 0.5, age at least 4 simulated seconds, or a near feature in the retained view. Bounds are initial experiment parameters, not biological constants. This first step checks continuity of movement and near/fine observation needs; it does NOT yet compare full parent-MB progress residuals or adapt interval to learned confidence. Reused absence is not new evidence of absence.

State and fresh/reused counters live under skyline actor prediction, already included in daily checkpoints. Resume gaps refresh. Default-off path still samples each tick. Test: experiments/rock_gate/predictive_skyline_checks.jl.

Ten-day trial: outputs/predictive-skyline-four-10d-20261103. Same input as rho-local-field-four-10d except this flag: four actors, sensitivities .5/.5/1/1, seed 20261007, finite 340 wild food, no regeneration, search resistance enabled. Existing configured first-day observation, daily provisioning, bodily priority, camp stay and post-success idle remain; no trade/aid/wildlife/processing. Compare behavior and actual reuse counters as well as runtime; behavior changes are possible.

## Adaptive interval revision (2026-11-03, replaces fixed-age policy in live integration)

Live day.jl now calls interval_skyline!. The earlier predicted_skyline! remains only as the prior prototype/test reference. Same opt-in scene flag, default false.

Confirmation interval begins at 1 second and doubles up to 16 when a scheduled fresh view agrees in the set of observed color/elevation/range-band features. This coarse agreement is provisional, not identity verification. Every tick the upper bound is recomputed as one quarter of time-to-contact: max(1, .25 * max(0, observed_distance - .75) / max(.01, recent_speed)). Distance is the closest current horizontal landmark/visible food/home observation, plus the uncertainty-adjusted home estimate when returning. No world coordinates or resource truth are read. Unknown distance and fine rho cap the interval at 2 seconds. The one-second simulation resolution remains the minimum; physical collision/food checks remain current.

A gap, goal change, increase of parent_mb.H_requested, stopping after motion or yaw change over 15 degrees triggers a fresh sample and resets interval to 1. Actual motion, not elapsed failure counts, updates recent speed. This uses the parent residual's cumulative charged increments, not all possible parent failures; repeated stable debt need not produce a trigger. Newly visible nearby cues shorten the bound even between skyline observations. A fresh feature mismatch also resets interval. Limits are experimental tuning constants, not configured action policies.

Between confirmations, only predicted bearings are advanced; no ray casting and no skyline observation count/home-memory admission. interval_observation records fresh/skipped, reasons, max_interval and interval_sum, and is included in existing skyline checkpoints. Near moving targets, dynamic scenery and social attention remain outside this static skyline experiment.

Tests: skyline_interval_checks.jl (including prior prototype tests). Ten-day fresh run: outputs/skyline-interval-four-10d-20261103; same four-actor seed/map/finite340 food settings as prior 10-day trial. Existing configured first-day observation, daily provision, body priority, post-success idle unchanged.

Initial adaptive launch stopped at tick 0 because the daily plan active value was nothing. Guard and three regression assertions added. Actual 10-day run: outputs/skyline-interval-four-10d-20261103-r2 (fresh restart, no state migrated from failed launch). Total unit assertions: 34.
