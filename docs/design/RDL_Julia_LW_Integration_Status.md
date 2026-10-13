# LW-Julia integration map and next work

2026-10-13 / reference e33758e. Behavioral fidelity policy applies; full Python
trace equality is not the acceptance criterion. B1g remains the finite learning
cycle baseline. Historical experiment reports retain their historical limitations.

## Execution identity

Python production LW: integrations/lightweight/integrated_social_campaign.py
configures timed_harvest.run and its layered World/agent adapters. Julia is still
an experimental subset, not a replacement production backend.

New common entry: experiments/julia_migration/lw_integrated/run.py -> run.jl ->
existing lw_day/run.jl. It composes the already accepted B1g capabilities, with
no new behavioral rule. Python exports geometry/clock; Julia owns the living loop.

| Area | Python reference | Julia status / explicit gap |
|---|---|---|
| Clock / repeated days | lw_time, timed_harvest | Continuous human_scale_v1, 1–4 days; sequential per-second actions |
| Body / load / eating | layered_body, body_exploration | walk/rest/eat with inventory load; no run/climb/drop, separate basal metabolism not fully ported |
| Food / stock | social_life, timed_harvest | acquisition, personal stock, retrieve/eat, fixed dawn top-up option; no full cargo World objects |
| Observation | World.cast, skyline/ground adapters | horizontal color fan and visible food; provisional home beacon, no full OBS coverage/skyline |
| Goal / method H | continuous_selection, nested models | shared BasicLoop food/home methods; not arbitrary canonical nested M_B |
| Routes | directional_routes, relational_movement | bounded observed color sequences; no full angular relation composition or route failure completion |
| Learned harvest | harvest_sleep/predictability, model_movement_field | B1g finite formation/use/difference/one replacement; local supplied schema, no canonical T1 |
| General Sleep | sleep_relation_review, sleep_auto_model, bundle_sleep | unported beyond harvest and local social expectation |
| Social | social_life, social_sleep, aid_pressure | current contact/request/give/refuse, actor-specific pressure and night expectation; response generosity still fixture-fixed |
| Ground | energy_exploration, ground_wear/appearance | constant resistance1.5; no spatial resistance, wear, recognized paths |
| Danger | moving_hazard, patrol_hazard, territorial_hazard | unported; current World contains static obstacles only |
| Rest cognition | rest_reactivation, movement rest | bodily rest present; episodic reactivation/mode switching unported |
| Transport | production observation/results receipts | local same-process scaffold, no Luanti/HTTP integration |

## Prioritized next boundaries

1. Common execution entry (this update): explicit seed/days/resource/learning
   switches, source manifest, compact result and short summary. Preserve B1g.
2. Current observed danger and safety interruption: first one fixed moving hazard,
   observation-relative evidence, safety choices, Sleep interruption and resumption.
   Reuse existing Python contracts; no predator learning or forced successful escape.
3. Body/ground coupling: spatial resistance, then run/climb/drop as separately
   declared finite adaptations. Do not silently call constant resistance a full field.
4. Broader social response and Sleep integration, followed by route/ground history.
   Sequence may change when an observed integration failure makes another gap urgent.

No requirement to finish all possible harvest refinements first. No campfire,
new sensory modality, universal relation discovery, or performance optimization
is added by this status update.

## Use

From repository root, with Python dependencies and the locked Julia environment:

```powershell
$env:RDL_LW_TIME_PROFILE='human_scale_v1'
python -m experiments.julia_migration.lw_integrated.run outputs/lw-julia --days 4 --seed 20261004 --food renewable --learning full
```

Defaults:3 days, seed20261004, finite food, full finite B1g learning.
Learning off leaves initial navigation/route recording/social behavior enabled;
it disables the harvest Sleep/model/field/review/replacement chain only.
Seed currently changes the existing sparse World layout; it is not a newly added
agent personality randomizer. Population remains A/B/C, not an arbitrary CLI size.

manifest.json describes exact config, spec hash, code hashes and unported scope.
summary.json reports physical terminal state, food and per-model counters;
result.json holds compact transitions/night snapshots. This is not full sensory
replay. Sleep completion and home return are reported outcomes, not forced by
the runner. Invariants check time, operation count, food ledger and finite body values.

The B1d reported sum is corrected to105 (A99+B1+C5), checked against saved
run38257579564. This arithmetic correction does not alter B1g's33 changes.
