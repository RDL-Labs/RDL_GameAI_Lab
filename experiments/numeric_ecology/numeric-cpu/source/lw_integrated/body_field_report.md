# Julia LW body_field living comparison

Source: 70fbbda. [Actions](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38354263925): 160 assertions PASS.

Body strain and hunger contribute to existing method priorities. Rest success does not resolve the food/home parent. Read-only counterfactual choice replaces deepcopy without mutating method state; 120 comparison assertions cover that boundary.

Seed 20261005, three actors, three continuous days, renewable food, mixed hazards. Each run executes 155,520 operations.

| Mode | Added food | Ground | Stock A/B/C | Carried | Consumed | Completed Sleeps A/B/C |
|---|---:|---:|---|---:|---:|---|
| off | 19 | 81 | 14/6/6 | 0 | 12 | 0/3/2 |
| on | 19 | 84 | 11/6/6 | 0 | 12 | 0/1/2 |

Body projection applied to 1,801 decisions; same-state choice changed in 89 (A54/B35/C0). These are diagnostic choice comparisons, not 89 independent trials.

The configurations differ between these two experiments: inertia also enables the angular relation field. Do not compare their off conditions as identical. Sleep pending is retained. Food supply depends on prior harvesting, so stock differences do not establish efficiency gains. Initial calls include compilation; no language speedup claim. Full Julia LW migration remains incomplete.
