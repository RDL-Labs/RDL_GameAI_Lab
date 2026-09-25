# Dynamic M_B Multi-Agent Regression Evidence

**Status:** DMB-C complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_dynamic_mb_multi_agent.py"
```

One sidecar runs complete cycles for `npc_a` and `npc_b`. Each agent has three
raw Experiences, one Sleep candidate, one canonical rupture, one material
bundle, one selection, one inactive reconstruction, and one cutover/re-entry.

Observed invariants:

```text
candidate A != candidate B
parent A != parent B
M_B'A != M_B'B
archive A does not affect B
M_delta A/B resolve independently
fresh window A/B starts independently
local action before == local action after
```

After both cutovers the active registry contains exactly `M_B'A` and `M_B'B`,
the archive contains exactly both parents, active `M_delta` count is zero, and
both retained phase records are `REENTERED`.
