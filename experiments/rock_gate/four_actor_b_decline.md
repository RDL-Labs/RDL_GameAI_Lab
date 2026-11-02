# B decline in the four-actor 180-day run

2026-11-03. Run: `outputs/navigation-four-180d-20261103-fixed`.
Read day-180 checkpoint daily history and event transitions; read-only replay
of day-127 checkpoint stopped immediately after B's first day-128 candidate choice.
No behavior change. This probe is a single-state reproduction, not a full-day
parity replay or an intervention establishing each factor's causal contribution.

| Day | Reserve at end | Walk operations | Carried food |
|---|---:|---:|---|
|126|92.52|185|none (deposit occurred)|
|127|73.29|95|1 raw acorn|
|128|54.09|0|1 raw acorn|
|129|34.89|0|1 raw acorn|
|130|15.77|0|1 raw acorn|
|131|0|6|1 raw acorn|

Days 128–130 have exactly 17,280 rests each, no scans, eating, pickup,
retrieval or processing. B was not immobilized initially by zero reserve.
Last successful deposit day 126. Personal stock remains 221 at the eventual
stopping point (19.4456351,17.7419789).

## Reproduced choice at day 128 start, us=2194560000000

Parent home H=0. Rest probability 0.9999901904338382 (99.999019%).
Rest priority -0.1051, learned reward 168.288, failure_count=0.
Next candidate `opening:0`: probability 0.0000048712, priority 1.8124,
reward 6.2235, failure_count=494, failure repulsion=9.6252, method H=21.
`step_0`: failure_count=872, failure repulsion=10.2084, method H=32.
Thus alternatives exist, but historical penalties and reward strongly favor rest.

Frozen home/search estimate: upper_actions=62,997, expected_actions=42,181.47,
progress_window=15,750; active actions=16,178, charged=0, scenes=4.
It is an experience-based censored estimate, not a demonstrated 62,997-step route.
The scene-count stagnation term requires fewer than two scenes; this episode
already has four. Home H stays zero through day 129 and reaches only .1594 at
day 130 end. These budgets are poorly aligned with remaining bodily reserves.

## Connected rules

- `day.jl`: hungry + raw carried food + no edible food + outside camp forces
  `returning=true`, after the body-purpose adapter selected food replenishment.
  This is given recipe routing, not MB comparison of alternatives.
- `basic_loop.jl`: rewards and failures attach to method names under each goal.
  `rest` is shared across situations; successful credited sequences can reward it.
  `rested` evidence currently means the rest action executed, not that energy
  maintenance or return progressed. Failure requires negative method evidence too.
- `mb_parent.jl`: home/search horizon is learned from completed and censored
  observations. No direct feasibility check against remaining bodily reserve
  appears in the cited residual calculation.
- `day.jl`: at reserve<=0 the fallback forces rest. Raw acorn cannot be eaten
  directly and preparation requires camp. Aid is disabled in this experiment.

The evidence supports a compound lock-in: raw-food return override, learned rest
dominance over heavily penalized movement, a permissive forecast, then zero-reserve
rest lock. It does not establish that navigation geometry alone caused the failure.
Fix evaluation should distinguish context-sensitive credit, actual rest benefit,
bodily feasibility of forecasts, and recipe knowledge as an option versus override.

Artifacts: `b-decline.json`, `b-rest-choice.json` under the run directory.
