# B1a: reusable local selection loop, continuous three days

Baseline 7b03a0a. Implementation and finite test; not full LW navigation parity.

Extract `BasicLoop` (goal, parent reference, H/threshold, method nodes, active
trial, last receipt, last 32 evaluations). Candidate generation, body execution
and result interpretation are separate adapters. The kernel does not know food,
home coordinates or social identity. Selection uses current candidates only,
score minus min(2,H/theta), least recently selected then name. Evidence resolves
method H separately from parent goal H. A successful step is not successful home
arrival. Unknown evaluation defers; accepted false evaluation adds one up to32;
confirmation resets that node. No lifetime action quota or daily H reset.

Source: `runtime/continuous_selection.py`, `nested_local_models.py`,
`goal_difference.py`, `home_search.py`, `local_return.py`. This ports their local
roles and bounded method penalty, not their full observation/schema algorithms.
Result replay is idempotent only for the most recently resolved trial; older
results reject. Single owner and one in-flight trial. Explicit snapshots hold
independent method fields; immutable event values are shared. No canonical T1.
Parent references do not yet implement arbitrary recursive goal replacement.

The food/home adapter asks whether an absent target was observed, whether the
same observed target got closer, or whether pickup/arrival occurred. A phase
change defers an unconfirmed prior trial. Search starts with survey; parent H
reaching theta admits currently feasible directions, with ongoing rescoring.
Unknown/blocked/body-limited directions are never revived. Existing priority
actions (food, replies, body rest, quiet night) remain outside this adapter.
Nearest visible food changing identity defers approach comparison; a scan with
no target increments its own method H, even if scenery changed.

The B0 beacon and simplified atomic turn+step remain. Learned route memory,
skyline matching, independent body rotation costs, global maps, hazard modes and
general Sleep are not added. Thus this closes the fixed unseen-home scan branch,
not the entire B1 navigation migration. Sleep still consolidates local aid only.

Run two existing layouts for three consecutive days with **one World**. Keep
position, body, inventory, private stock, social/aid state and loop H; only create
the next day's Sleep cycle. Snapshot the previous endpoint and next start to
check continuity. No resource replenishment. A separate one-day stock control
starts A with two private units and verifies retrieval followed by eating.
That control is not claimed as naturally acquired stock on a later day.

Verify generic kernel under food/home/arbitrary names, method vs parent evidence,
defer, wrong/unaccepted/duplicate/conflicting results, current feasibility, all
operations counted, food conservation, night completion, and day continuity.
Compare B0 one-day counts diagnostically. Do not require all agents to return.
Performance work remains paused; elapsed values are not paired benchmarks.
