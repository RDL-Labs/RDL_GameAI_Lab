# LW-Julia integration map and next work

2026-10-13 / reference e33758e. Behavioral fidelity policy applies; full Python
trace equality is not the acceptance criterion. B1g remains the finite learning
cycle baseline. Historical experiment reports retain their historical limitations.

## Execution identity

Python production LW: integrations/lightweight/integrated_social_campaign.py
configures timed_harvest.run and its layered World/agent adapters. Julia is still
an experimental subset, not a replacement production backend.

Native entry: experiments/julia_migration/lw_integrated/native.jl -> run_integrated
-> lw_day. Julia generates the World and clock, executes the living loop and writes
results. The run.py export entry remains for historical Python-generated layouts.
Both compose the same B1g capabilities and optional finite hazard adapter.

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
| Ground | energy_exploration, ground_wear/appearance | optional finite resistance patches, local five-direction effort and candidate contribution; no wear or recognized paths |
| Danger | moving_hazard, patrol_hazard, territorial_hazard | finite optional crossing/relative sensing/override/release connected; damage, territory and full safety-method selection unported |
| Rest cognition | rest_reactivation, movement rest | bodily rest present; episodic reactivation/mode switching unported |
| Transport | production observation/results receipts | local same-process scaffold, no Luanti/HTTP integration |

## Prioritized next boundaries

1. Common execution entry (this update): explicit seed/days/resource/learning
   switches, source manifest, compact result and short summary. Preserve B1g.
2. Current observed danger and safety interruption: finite adapter connected; one fixed moving hazard,
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

Julia-only (no Python environment or pre-generated input required):

```powershell
julia --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/julia/setup.jl
julia --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/native.jl outputs/lw-native --days 3 --seed 20261004 --food renewable --hazards crossing
```

`--learning off|full` defaults to full. All defaults otherwise match the previous
entry. To reproduce a saved input without configuration overrides:

```powershell
julia --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/native.jl outputs/lw-replay --spec outputs/lw-native/spec.json
```

Native generation is versioned `julia-lw-sparse-mt-v1`, using MersenneTwister in
locked Julia 1.13.1. It preserves the finite layout recipe (22 generated objects,
6 retained solids, 8 resource sites with 12 units each, three initial agents),
not Python's random sequence. Equal numeric seeds across the two generators do
not mean equal terrain. Use frozen specs for equal-World comparisons. No rejection
sampling guarantees accessible resources or successful return.

The native manifest records generator, Julia version, spec hash and Julia source
hashes. The calibrated human_scale_v1 clock is checked explicitly; other clock
profiles remain unsupported because body/Sleep rules share that calibration.
The workflow `julia-lw-native.yml` installs/runs Julia only. This removes Python
from this finite runtime path, not from the repository's reference tests/tools.

`--ground flat|shadow|patches` defaults to flat. Shadow and patches use the same
two World-owned resistance regions (0,5,radius3,resistance4 and
12,12,radius6,resistance3); only patches applies extra effort to candidate ranking.
The agent sees five immediate samples, not region centers or a global cost map.
Each sample evaluates the midpoint of the actual half-unit, damage-scaled step.
Execution samples that same World point again. Overlap uses maximum resistance;
outside regions the baseline remains 1.5. This is a discrete local approximation,
not a continuous path integral or learned terrain map.

Ordinary movement candidates receive priority minus
`0.25 * max(0, resistance - 1.5) * (1 + 0.1 * load)`, the calibrated reserve-effort
excess over flat ground. Existing method identity and feasible candidate set remain
unchanged. Safety retains its own priority. If no move is feasible, the existing
survey method stays separate; no movement method is relabeled as successful rest.

Accepted movement diagnostics retain at most32 source-bound records per agent:
load, resistance, expected/actual body deltas and status. Counters retain totals.
The existing one-unit observed clearance and half-unit execution horizon differ;
delta equality is evaluated only with matching clearance and load. These records
are experience material/diagnostics, not a newly adopted Sleep or terrain M_B.
Ground-dependent generalized Sleep learning remains unported.

Dedicated testsets are now in checks.jl and explicit validation entry points;
normal native startup no longer runs them. Runtime conservation assertions remain.

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

## Common-entry verification

### Subsequent finite hazard adapter

`--hazards crossing` enables a fixed World trajectory during seconds 60–180:
start (0,8), velocity (0.05,0). Policy receives only current relative direction
and distance, within 12 units, front half-plane and static line of sight.
The hidden trajectory and schedule are not policy inputs. Off remains default.

Observed threat interrupts food/social/night selection. Safety chooses an already
feasible direction increasing separation from the nearest observed threat, or
scans if none exists. New sightings reset local warning-basis H; each complete
sample without a sighting adds 2, and threshold 8 provisionally releases the
override. This is not proof of safety. Safety movement earns no route support.
Night scanning/walking interrupts Sleep through its actual-result receipt path.

This synchronous one-second adapter is not full Python safety parity or canonical
Core H. No damage, territory, chase, predator learning, guaranteed escape or
asynchronous observation binding is introduced. The fixed crossing is a finite
integration stimulus; broader safety-method H and partial sensing remain unported.

Validation: code `043176b`, [run38333622109](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38333622109).
16 local sensor/selection assertions and 4 integrated invariants passed per run.
Hazard-on sparse seed20261004 completed one day: A entered/released 9 times
(50 override decisions), B 7 times (40), C zero. All completed Sleep. Food ledger:
100 = ground50 + private stocks47 (A33/B2/C12) + consumed3; carried zero.
Repeated entries are allowed when the threat becomes visible again after a
provisional release. This is not proof of efficient escape or stable avoidance.
The stimulus ends before night; actual night interruption was not exercised by
this run. This remains a separate acceptance boundary.

The hazard-off four-day result matches run38331924163 exactly after removing the
new top-level `safety=null` diagnostic. No repository-wide suite or performance
comparison was run for this increment.

### Original common-entry verification

Code baseline: `e9360f7`. GitHub Actions run
[38331924163](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38331924163)
completed successfully with days=4, seed=20261004, renewable food and full learning.
The four invariant assertions passed. All three agents completed four Sleep cycles
and executed 69,120 operations each (207,360 total). Final private stocks were
A=101, B=77, C=107; carried food was zero. Food conservation was
100 initial + 197 replenished = 6 ground + 285 stored + 6 consumed.
All three agents used a replacement harvest model.

The downloaded `result.json` was compared structurally with run38327891851's
`scenes.lw_sparse.enabled`: exact equality. This diagnoses that the common entry
preserved this existing B1g case; exact historical trace equality remains optional
under the behavioral-fidelity policy. This is one four-day configuration, not full
LW acceptance, a performance comparison, or a rerun of the repository-wide suite.

## Native-entry evidence

See [native execution report](../../experiments/julia_migration/lw_integrated/native_report.md):
two native seeds, three days each, frozen-input replay, 42 checks passed; existing
exported-layout regression preserved. Generation and all execution are Julia;
unported capabilities in this map remain unported.

Ground integration evidence: [three-condition report](../../experiments/julia_migration/lw_integrated/ground_report.md),
48 assertions passed. High-resistance traversal attempts changed, but food storage
did not improve. Flat-mode historical result is preserved.
