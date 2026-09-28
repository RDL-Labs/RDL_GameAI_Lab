# L15A — Six-agent continuous exploration

Status: IMPLEMENTED; actual run interrupted on day 16.
[World evidence](../experiment-evidence/LUANTI_L15A_six_agent_world_evidence.md): 36 units / two returns, not clean acceptance.

Six-agent opt-in: `ReturnCampaign(..., agent_count=6)` / runner `--agents 6`.
The default remains three agents with legacy configuration and snapshot shape.
The six-agent mode requires steady profiles; arbitrary population sizes and mixed
six-agent profiles are not part of this experiment.

## Fixed experiment

- Six independent A/B/C/D/E/F agents in one natural_meadow World.
- Existing A/B/C start x positions 0/-2/2 retained; D/E/F start at -4/4/6, z=0.
  Heights come from the World terrain; all start facing the same direction.
- Eight shared resource patches, twelve units each (96 total), no replenishment.
- Thirty 64-second days at 1×, or six aggregate returned batches, whichever first.
  A batch means an agent/night with previously uncounted pickup operations, not
  a unit count or a requirement that every individual returns once.
- Current-harvest state and model field enabled. Existing budgets remain per-agent.
- Configuration waits for all six agents. Per-step response execution order rotates
  across all six. Completion waits for all six finish receipts. Shared stock is
  mutated only by the existing sequential World pickup execution.
- Bodies retain the existing nonphysical entity configuration: this does not test
  body-to-body collision avoidance or negotiated cooperation.

Runtime agents own separate observations, results, sensory stores, learning records,
models and body-operation references. Population count binds at configuration;
foreign observation or operation references are still rejected. A six-agent setup
does not give the existing three-agent entry points permission for D/E/F.

No new selection rule, model reconstruction, sleep mechanism or resource-regrowth
learning is added. Current absence continues to coexist with historical success;
combined harvest/persistence model invalidation remains unchanged.

## Validation

Dedicated six-agent tests exercise independent actual admission paths for all six,
replay, foreign references, population binding, supported counts and six-batch
counting. Existing three-agent fixture replay remains a regression requirement.
Actual World result and timing acceptance are reported separately; an acquisition
slot miss or expired action will not be relabelled a clean acceptance.

```powershell
python -m integrations.luanti.tests.run_return_campaign --agents 6 --periods 30 --speed 1 --model-field enabled --harvest-state --output integrations/luanti/output/six-agent.json.xz
```
