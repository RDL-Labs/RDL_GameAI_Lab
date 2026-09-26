# Luanti RW1 Multi-Agent World Evidence

## Commands

```powershell
& .\integrations\luanti\scripts\test-multi-agent.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l0-l2.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l3.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l7.ps1 -LuantiRoot D:\luanti
python -m unittest discover -s tests
```

## Result

Luanti 5.17.0 and one Runtime produced:

```text
MULTI PASS: agents=2 independent_pickups=true canonical_agents=2 radius_counts=A:2,B:1
```

The World log contained both independent resolutions:

```text
pickup agent=npc_a target=food_a
pickup agent=npc_b target=food_b
complete agents=2 independent_pickups=true
```

The Runtime canonical snapshot retained `latest_sections.npc_a` and
`latest_sections.npc_b`. Existing single-agent L0-L2, L3, and L7 real-Luanti
verticals passed after the fixture-mode branch was added.

At the final pickup position, `npc_a` observed the inside `npc_b` and the marker
exactly 12 units away, while excluding the marker 12.25 units away. `npc_b`
observed only the inside `npc_a`; both markers were outside its radius. The
canonical finite counts therefore fixed boundary inclusion and outside exclusion.
