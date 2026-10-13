# Native Julia LW entry: World through terminal output

2026-10-13 / implementation `7a7e389`.

Scope: the existing finite Julia LW subset now runs without Python input export
or a Python subprocess. `world.jl` creates the calibrated clock and sparse layout;
`native.jl` writes the frozen input/manifest, calls the shared living loop and saves
result/summary. Existing Python reference and export entry remain available.
This is not full LW migration: general Sleep/T1, rich social response, variable
ground resistance/path wear, run/climb/drop and full hazard behavior remain gaps.

## Configuration and reproduction

World generator `julia-lw-sparse-mt-v1` uses Julia 1.13.1 MersenneTwister.
The recipe preserves object/resource counts and ranges, not Python RNG identity.
Equal numeric seeds across generators are not equal Worlds. A saved `--spec`
owns its configuration, cannot be mixed with CLI overrides, and bypasses generation.
Manifest records the spec SHA-256, Julia source hashes and Julia version.

## Cloud evidence

[Julia-only run38334456523](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38334456523)
used Julia setup and execution only, with no Python setup/export command.
Two native seeds ran for three continuous days each with renewable food, full
finite harvest learning and the fixed crossing hazard. The first input was also
replayed in full from its saved spec.

Checks: safety16 + native generation/configuration12 + invariants4 per execution
(three executions) + frozen replay2 = 42 assertions passed. Each execution has
155,520 operations (51,840 per agent). Replayed result and spec match exactly.
This replay is a determinism diagnostic, not a universal migration acceptance rule.

| Native seed | Initial + added | Ground | Private stock A/B/C | Carried | Consumed | Sleep complete by night |
|---|---|---|---|---|---|---|
| 20261004 | 100 + 90 | 84 | 29 / 17 / 36 | 18 | 6 | all agents, all three nights |
| 20261005 | 100 + 76 | 47 | 57 / 60 / 0 | 5 | 7 | A/B all; C only night2 |

Both resource ledgers balance. Seed04 ended away from home with six units each;
seed05 ended with A/B near home and C away with five units. Sleep completion is
not equivalent to home return. C's incomplete nights remain outcomes, not forced
success. No causal attribution of these seed differences to any single mechanism
was tested. Replacement harvest models formed for A in seed04 and A/B in seed05.

Hazard entries/releases: seed04 A0/B0/C4; seed05 A5/B3/C6. The crossing ends at
second180, so this still does not exercise a night-time hazard interruption.

Scenario call times were 30.82s (first native run), 18.27s (frozen replay), 16.68s
(second seed), within one process. First-call compilation, terrain and histories
differ; setup and output serialization are outside those call times. These are
not Python/Julia speedups or end-to-end runtime guarantees.

[Existing-layout run38334536864](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38334536864)
also passed: old four-day hazard-off and one-day hazard-on results matched
run38333622109 structurally. The shared-function refactor preserved those cases.
The repository-wide suite was not rerun as part of this experiment.

## Next integration boundary

Execution ownership is now Julia from generation through persistence. Continue
porting missing behavioral capabilities into this entry, rather than creating a
separate miniature lifecycle for every feature. Current priority: observed local
ground resistance/body cost, followed by finite run/climb/drop adapters. Keep the
native generator version and frozen specs explicit when comparing behavior.
