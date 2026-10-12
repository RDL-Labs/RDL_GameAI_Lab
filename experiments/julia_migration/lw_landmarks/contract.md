# B1b observed landmark and directional route adapter

Baseline afc747f. Opt-in `landmark_routes=true` requires the B1a basic loop.
This reconnects finite directional-color route roles from existing LW, not the
entire LW navigator. No campfire, global map, new survival rule or performance goal.

Source modules: LW World.cast / horizontal fan, landmark_exploration,
directional_routes (MAX_ROUTES16/MAX_POINTS8), relational_movement route_strength.
Julia fan: 13 horizontal rays, +/-90°, range48, observer height1, nearest surface,
exclude ochre tower. Color/azimuth/range band only cross into policy; no object ID
or exact position/distance. Compare six fan fixtures with actual Python World.cast.
The existing provisional home beacon is unchanged; elevated skyline is not ported.

Adjacent same-color patches merge. Multiple disjoint same-color patches are
ambiguous, not an arbitrary winner. Currently observed non-near unambiguous
patches may become movement candidates. Only currently feasible movement rows
are proposed. Direct currently observed food/home suppresses route detours.
Landmark step evaluation asks whether actual movement succeeded; it does not
claim arrival, target identity or parent goal success.

Record pre-movement observations only after actual walking. Outbound trail must
start from observed home contact; inbound trail starts after an actual pickup.
Maximum8 color changes; overflow/incomplete trail cannot be admitted. Only an
actual deposit containing that same pickup grants bounded support. Initial food,
gifts and consumed pickups cannot substitute for that unit. A per-agent cargo
provenance list tracks actual pickup/eat/give/deposit; retrieval has no new-pickup
credit. Its length is audited against physical inventory after every operation.

Direct route support max8, per-route actual blocked H max32; reverse order is an
unsupported proposal, support0 until its own successful leg is recorded. Receipt
deduplication window32; route capacity16. No truncation of an overflowing trail.
Current observation re-identifies color at the route cursor; absent/ambiguous/
partial observation gives no route direction. Near patch advances cursor; it
does not count as home/food success. Cursors reset per day/deposit, routes persist.

Adaptations: SHA signatures replaced by explicit goal/color sequence keys;
bounded route strength `(1+.25support)/(1+H)` biases BasicLoop candidates.
Best feasible direction toward each observed patch is proposed; atomic turn-step
remains B0 behavior. Full multi-landmark angular relation field, learned sequence
completion failure evaluation, active patch tracking through occlusion and
skyline memory are NOT ported. Local BasicLoop H and physical blocked route H
remain distinct. No new freeze/stop quotas. Final output may differ from Python.

Test native admission, ownership/provenance, duplicate support, reverse proposals,
overflow, absent/ambiguous/partial/blocked current observations. Run two existing
scenes, enabled/disabled, three continuous days; preserve food/Sleep/continuity
checks. Save route admissions/selections and observer-only maximum radius in
addition to compact transitions. World-truth radius never enters decisions.
No success/efficiency requirement or coefficient fitting to a desired result.
