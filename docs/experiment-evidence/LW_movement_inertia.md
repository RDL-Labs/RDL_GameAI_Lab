# Finite movement inertia comparison

Status: implementation and 23 boundary/regression tests passed; cloud comparison pending.

Default remains disabled. The opt-in movement_inertia gate retains a confirmed
nonzero move in the same exploration/return phase with a currently sampled flat
front surface, complete empty hazard observation, no visible food and no protected
action. It does not repeat turn commands. Unknown input is not clearance.

Local repetition H increases by one for an unchanged subjective signature and
resets on a changed signature. Threshold 4 requests normal method selection.
This is a GameAI-local repetition proxy, not canonical H or a proof of goal progress.
Body linkage, body feasibility and energy checks remain active. A body-limited
wait does not receive movement success credit. Phase changes, protected work,
failed movement, threat evidence and incomplete surface interrupt continuation.

While continuing, horizon candidate expansion and Sleep/body-method/bundle/trail
candidate reranking are skipped. Observations, upstream proposal generation and
existing state/history processing still run. This is not a complete event-driven
thinking architecture, nor a smooth continuous physics steering implementation.

Manual workflow lw-inertia.yml compares disabled/enabled sequentially on Ubuntu
24.04, Python 3.12.15, seed 20261005, three agents, one-second observations,
600 World seconds each. No three-day rerun or speedup claim is made yet.
