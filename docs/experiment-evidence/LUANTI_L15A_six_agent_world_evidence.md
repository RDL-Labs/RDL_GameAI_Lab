# L15A — Six-agent actual World evidence

Status: SIX-AGENT IMPLEMENTATION VERIFIED; ACTUAL RUN INTERRUPTED, NOT CLEAN ACCEPTANCE.

Date: 2026-09-29. Baseline `a8bd9f1` plus the source-hashed six-agent changes.
Run `l15campaign-562d9579ae5c`. [Contract](../experiment-contracts/LUANTI_L15A_six_agent_campaign.md).
All recorded implementation hashes match the tested checkout.

## Predeclared experiment

One actual continuous World, A/B/C/D/E/F, natural_meadow, all steady, eight shared
patches with twelve units each, 1× speed. Maximum thirty 64-second days or six
aggregate returned batches. Current harvest state and model-field projection enabled.
No behavior parameter was adjusted during the run; no retry replaced this attempt.

## Outcome

| Agent | Actual pickups | Pickup days | Returned batches | Model admitted / later invalidated |
|---|---:|---|---:|---|
| A | 0 | — | 0 | no / no |
| B | 12 | 9 | 1 | yes / yes |
| C | 12 | 10 | 0 | yes / yes |
| D | 0 | — | 0 | no / no |
| E | 12 | 1 (3), 3 (9) | 1 | yes / yes |
| F | 0 | — | 0 | no / no |

36 units acquired, 60 remaining, two of six requested return batches. C's twelve
acquisitions were not counted as a return. A/B/C's start positions remained unchanged;
D/E/F were additional starting positions. This is not a matched timing experiment,
and does not prove population size caused any particular individual difference.
Bodies do not collide in this fixture. Resource access is shared, with World-owned
sequential pickup, not negotiation or social learning.

The run stopped at `968267901` microseconds (day 16 after fifteen full days), with
`missed acquisition slot`. Maximum World step was `417334` microseconds, exceeding
the 250 ms acquisition interval. The source of that delay is unestablished; six-agent
load is a possible hypothesis, not an observed causal result. The previous three-agent
run also had a slot interruption under different timing conditions.

The prefix additionally contains 58 expired and two stale action results. Runner exit
was 1 and strict acceptance false. Both World and live Runtime were preserved before
rejection. No missing slot was filled synthetically and no action budget was extended.

## Verification

- 3,870 observations per individual, 23,220 total. Every current-harvest state matches
  recomputation from the individual's observation and already available own records.
- All 46,441 saved HTTP responses replay exactly; the final replay Runtime snapshot
  matches the actual saved snapshot. This is prefix verification, not full-run acceptance.
- Returned batches independently recounted from actions and pickup IDs match the
  recorded B/E returns. Shared stock checked through every before/after event:
  96 initial = 36 unique pickup operations + 60 remaining; no negative stock, duplicate
  pickup operation or discrepancy with summed inventories.
- Current absence coexists with B/C/E's retained twelve successful acquisition records.
  No absent-state pickup command was selected. Combined persistence models remain
  invalidated; no new acquisition-only model or periodic regrowth was inferred.
- Model-field applications: zero for all six. No learned movement improvement claimed.
- 49 related Python tests PASS, including three dedicated six-agent tests, legacy
  three-agent World replay, individual learning/isolation, population binding,
  three/six return counting, current availability, failure preservation and portability.
- PowerShell launcher parsed successfully; actual Luanti loaded and executed the changed
  Lua fixture. The full repository suite was not run locally. The prior CI fix at
  `a8bd9f1` was confirmed green before this change.

An initial ad-hoc stock audit treated Lua's empty inventory `null` as a Python list
and failed while counting empty inventories. Normalizing that representation to an
empty list made the complete stock audit pass; no World or Runtime data was changed.

## Artifacts and reproduction

- `tests/fixtures/luanti_l15a_six_agent_world.json.xz`: actual interrupted World/Runtime.
- `tests/fixtures/luanti_l15a_six_agent_world_audit.json`: replay, counts and source hashes.

```powershell
python -m integrations.luanti.tests.run_return_campaign --agents 6 --periods 30 --speed 1 --model-field enabled --harvest-state --output integrations/luanti/output/six-agent.json.xz
python -m integrations.luanti.tests.analyze_current_harvest_world tests/fixtures/luanti_l15a_six_agent_world.json.xz --replay --output integrations/luanti/output/six-agent-audit.json
```

The second command validates the interrupted prefix and current state. It does not
turn a missed acquisition slot into a successful campaign acceptance.
