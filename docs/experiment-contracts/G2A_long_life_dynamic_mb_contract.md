# G2-A Long-Life Dynamic M_B Contract

## Purpose

Connect existing Food, Safety, Sleep, Experience, and Dynamic `M_B` slices across
one finite day boundary without introducing a general need arbitrator.

## Reference Path

```text
day 1 Food
-> danger interruption
-> Safety escape
-> Food resume / deposit
-> second Food success
-> explicit Sleep mode
-> real Sleep completion
-> S1-S3 shadow CandidateRelation
-> explicit review / M_delta / T1 / inactive M_B'
-> explicit cutover / REENTERED
-> same Godot World continues
-> day 2 cue-free autonomous Food / deposit
```

## Mode Boundary

`FoodSafetySleepCoordinator` accepts exactly one Godot-owned mode:

```text
FOOD_SAFETY xor SLEEP
```

It delegates to existing policies. It does not compare needs, infer a day/night
cycle, create `H`, select T1 materials, activate `M_B'`, or grant canonical action
authority.

## Acceptance

1. Day one contains two real Food successes and one Safety interruption/resume.
2. The same Godot process completes bounded Sleep and forms a sourced candidate.
3. Runtime performs the existing explicit DMB path while Godot waits.
4. Godot observes cutover and continues without resetting the World provider.
5. Day two disables the cue and completes Food from `learned_low_stock_relation`.
6. Assisted success count remains two; autonomous completion does not invent a third cue-bound result.
7. G2-A remains single-agent. Multi-agent multi-day validation is G2-B.
