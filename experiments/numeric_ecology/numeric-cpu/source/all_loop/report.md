# ALL-loop A0 results

FINITE STANDALONE EXPERIMENT COMPLETE. Full LW integrated port NOT COMPLETE.

Measured code: `950e573aa5296ccbbafbf350b1cb3f4a1a1ada16`.
[Successful Linux run](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38219271539).
Julia 1.13.1 with unchanged pinned environment; Python 3.12.15; Ubuntu 24.04,
Linux 6.17.0-1022-azure x86_64, one thread. CPU model was not recorded in the
report; both languages run alternately on the same job. No cross-run CPU comparison.

## What ran

Both backends own the entire minimal World → observation → candidate evaluation →
action → body/resource update loop. Julia never invokes Python during simulation.
The Python supervisor only creates shared JSON, launches processes and compares outputs.

Existing geometry, walk/rest/eat body equations and energy candidate costs are reused
in Python and ported in Julia. A new explicitly experimental visible-food policy and
atomic orientation-plus-walk operation are common to both. They are NOT the existing
LW steering, M_B/E/H/theta, learned models, Sleep or social selection. No production
runtime or World was replaced. The complete rich LW observation packet is not generated.

Thus A0 answers whether a small self-contained Julia simulation can preserve its
declared behavior while avoiding J3's per-batch boundary cost. It does not measure
the speed of a complete LW integrated Julia replacement.

## Behavior and equivalence

Five cases × 3 agents × 600 one-second ticks = **9,000 compared steps**.
Every visible observation, candidate evaluation, action, outcome, body state and stock
matches under the preregistered continuous tolerance (absolute/relative 1e-12).
Discrete actions, indices, counts and Boolean values match exactly. A repeat from
initial state matches for both backends. Every timing run also checks outcome counts.

| Case | Walk | Rest | Pickup | Eat |
|---|---:|---:|---:|---:|
| Open, initial reserve 79 | 1,761 | 0 | 36 | 3 |
| Obstacles | 1,632 | 132 | 36 | 0 |
| Enclosed | 0 | 1,800 | 0 | 0 |
| Low reserve | 0 | 1,800 | 0 | 0 |
| Shared two-unit stock | 1,798 | 0 | 2 | 0 |

Food conservation is asserted in both implementations. Python's original body
validation and Julia's body-bound assertions run during updates. Blocked samples and
body-limited samples are exercised separately. The enclosed and depleted cases remain
at rest: A0 has no H-driven escape, rescue or new-model generation. This is a limitation
of its intentionally small policy, not evidence of production agents behaving that way.

## Performance

Each process warms every scene once and runs three timed fresh-state repetitions.
Five alternating process pairs. Table values are median of the five per-process
medians, in milliseconds per complete 3-agent/600-tick scene. Timings include World
state initialization and all loop updates, exclude JSON file I/O and step trace saving.

| Case | Python ms | Julia ms | Python / Julia |
|---|---:|---:|---:|
| Open | 173.551 | 22.151 | 7.83× |
| Obstacles | 207.175 | 21.326 | 9.71× |
| Enclosed | 205.479 | 20.162 | 10.19× |
| Low reserve | 163.207 | 21.933 | 7.44× |
| Shared stock | 172.253 | 19.769 | 8.71× |

This includes implementation/data-representation effects: Python uses original
dictionary/deepcopy-based body and energy functions, while Julia uses typed body
state and avoids constructing unneeded candidate dictionaries when tracing is off.
It is not an isolated language-only benchmark or an optimized-Python comparison.

Whole benchmark process wall time (startup, loading, compilation, warmups, all five
scenes and their repetitions, output): Python **3.771–3.823 s**, Julia **3.823–3.925 s**.
The cold trace-producing process took Python 1.422 s and Julia 5.127 s. Neither metric
isolates startup alone. Short processes do not obtain the warm-loop speed ratio.

Maximum RSS for benchmark processes: Python **15,936–15,972 KiB**;
Julia **382,052–397,764 KiB** (approximately 24–25 times Python).
Trace-producing processes reached Python 82,256 KiB and Julia 513,932 KiB.
Julia's substantially larger memory footprint remains a cost; no unconditional
production adoption is justified by the warm timing.

## Development and verification record

- First run `38218901932`: Julia parser rejected ambiguous `1.+...`; changed to `1.0+...`.
- Second run `38219096456`: loop executed, comparator rejected continuous strain
  JSON spelling `1` versus `1.0`. Named continuous fields now use numeric tolerance;
  no discrete checks were relaxed. Downloaded traces then matched all 9,000 steps.
- Third run `38219271539`: equivalence, repeatability, conservation, scenario checks
  and all five timing series passed.
- Three comparator regression tests were added afterward and passed locally. They
  check numeric spelling, strict discrete values and missing evidence rejection;
  the workflow now invokes them. Simulation and measured timing code are unchanged.
- The full repository test suite was not rerun. Production Python files are unchanged.

## Next boundary

The self-contained execution approach is worth extending. Next, port a bounded
existing selection mechanism including its M_B/E/H/theta state and compare its
transitions; then add Sleep and social behavior with their existing acceptance cases.
Keep these as explicit parity stages. Do not extrapolate 7–10× to the current
47-minute integrated run, and do not silently substitute this fixture policy for it.

## Raw evidence

Local directory: `outputs/julia_migration/cloud-38219271539/`.
It contains both full traces and replays, ten timing results, process resource files,
shared scene JSON and `report.json`. Generated outputs are not checked into Git.
GitHub artifact retention is 14 days; raw download is retained locally.

Input SHA-256: `22e5146d87a2192f2f69e1abde574613ad17ed1b4ab7b6e517f6ad4536157e06`.

Downloaded `artifacts0.zip` SHA-256:
`bc11ed0167f969be8b0207092260d07d311444f309b63321864783f988937c6e`.
