# Luanti RW2 Multi-Agent Food Life Evidence

## Command

```powershell
& .\integrations\luanti\scripts\test-multi-agent.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l0-l2.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l3.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l7.ps1 -LuantiRoot D:\luanti
python -m unittest discover -s tests
```

## Result

Verified with Luanti 5.17.0 on 2026-09-26.

```text
pickup agent=npc_a target=food_a
pickup agent=npc_b target=food_b
deposit agent=npc_a base=base_a accepted=true
deposit agent=npc_b base=base_b accepted=true
complete agents=2 results=2
MULTI LIFE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:2,B:1
```

The Runtime life snapshot must contain exactly two accepted results with
distinct agent, result, source observation, and cue identities. This evidence
does not claim shared-resource competition, danger handling, Sleep, learning,
or M_B-informed behavior.

The repository suite passed with 309 tests and 46 intentional skips. Existing
real-Luanti L0-L2, L3, and L7 verticals also passed after RW2 was added.
