# ALL-loop A0: standalone Julia execution experiment

Authorized after J3 by the user's request to try ALL Julia. This is the first
finite standalone loop, NOT a port of the complete LW integrated campaign.
Production Python remains untouched. Stop after A0 results before expanding scope.

Port the frozen World geometry from J2 and the current `layered_body` walk/rest/eat
and `energy_field` cost/feasibility rules under human_scale_v1. Use a declared NEW
minimal fixture policy in BOTH languages: visible food approach, five body-relative
movement candidates, energy ranking, pickup, eat below reserve 80, otherwise rest
if no move is feasible. No hidden food coordinates enter selection; only relative
visible food and sampled candidate clearance do. No random choice inside the loop.

The fixture policy is not existing M_B/E/H/theta selection. Those mechanisms,
Sleep, return, social relations, danger, rich sensing and learned models are
NOT ported in A0. Do not call this the LW integrated Julia backend. No claims
about LW campaign speedup or behavioral equivalence may follow from A0 timings.

Three agents update sequentially A/B/C over 600 one-second ticks. Five scenes:
open food, obstacle detour, enclosed agent, low reserve, and shared contested food.
Scene layout is common JSON, generated once in Python before timed runs. Each
backend owns World, geometry, observations, selection and body/resource changes
throughout the loop. Julia never calls Python. JSON is read before timing and
written afterward. Correctness runs save every step, performance runs do not.

Compare every observed candidate, action, status, position, body and stock with
strict discrete agreement and atol=rtol=1e-12 for floating numbers. A numerical
boundary changing choice fails. Assert inventory conservation, no negative stock,
body bounds, independent state on replay, and that cases exercise pickup/eat,
blocked observations, rest and body limitation. No guaranteed food success.

Five alternating process pairs, one thread, same Linux runner and locked Julia
1.13.1 environment. Report cold process wall time separately from warm complete
loop time; warm each scene then three repetitions from initial state. Include
state initialization in loop timings, exclude file I/O and correctness trace
construction symmetrically. Retain all timings and /usr/bin/time RSS. Do not use
profilers in timing, fast-math, GPU, parallelism or altered observation cadence.
