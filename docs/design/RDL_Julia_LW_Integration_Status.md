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
| Body / load / eating | layered_body, body_exploration | walk/rest/eat, optional danger-running, low-obstacle climbing and finite one-unit drop/recovery; opt-in basal metabolism/hunger/provision and giving-retention connected |
| Food / stock | social_life, timed_harvest | acquisition, personal stock, retrieve/eat, fixed dawn top-up option; bounded dropped-food objects with provenance, no general cargo planning |
| Observation | World.cast, skyline/ground adapters | horizontal color fan and visible food; provisional home beacon, no full OBS coverage/skyline |
| Goal / method H | continuous_selection, nested models | shared BasicLoop food/home methods and persistent return purpose across load changes; not arbitrary canonical nested M_B |
| Routes | directional_routes, relational_movement | bounded observed color sequences; no full angular relation composition or route failure completion |
| Learned harvest | harvest_sleep/predictability, model_movement_field | B1g finite formation/use/difference/one replacement; local supplied schema, no canonical T1 |
| General Sleep | sleep_relation_review, sleep_auto_model, bundle_sleep | bounded review and opt-in walk/scan action-model use connected; finite per-record dormancy/reactivation connected; full vocabulary/context and conjunction bundles unported |
| Social | social_life, social_sleep, aid_pressure | current contact/request/give/refuse, actor-specific pressure and night expectation; optional own-refusal/body-conditioned response; legacy generosity remains fixture-fixed |
| Ground | energy_exploration, ground_wear/appearance | optional finite resistance patches, local five-direction effort and candidate contribution; shared walking wear/recovery verified; local appearance/sampled shape recognition verified; body-linked ground continuity and exploration following verified |
| Danger | moving_hazard, patrol_hazard, territorial_hazard | crossing plus fixed territorial/patrol World response connected; relative sensing/override/release; damage and full safety-method selection unported |
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

## Deferred idea: cargo loss versus alternative methods

2026-10-13 / after `19b88b9`. DESIGN ONLY; explicitly deferred by the user.
Prioritize Julia LW integration and the existing Python LW capabilities. Do not
expand drop planning or reorganize generic/specialized layers as a prerequisite.
The next planned integration area remains broader social response and general
Sleep, followed by route/ground history in the same native living loop.

A future return-purpose comparison may weigh how much food would be left behind
against retaining the cargo through a detour, another crossing, or recovery rest.
Leaving one unit may favor climbing; leaving most of the load may favor another
method. This is not a fixed item-count rule: body cost, danger, observed route
experience and method H may change the balance. Dropped cargo is not necessarily
lost permanently; another individual may recover it. Do not assume unseen routes
are feasible or grant the agent the complete World map.

Current implementation only proposes a one-unit drop when it makes a locally
observed low obstacle climbable. Multi-unit drop planning and explicit cargo-loss
valuation are unimplemented. Return-purpose continuity is already implemented;
that does not imply this future comparison exists. This note changes no behavior,
coefficients, observations or test acceptance criteria.

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

`--running off|on` defaults to off. On adds five run samples only for danger
response. Run distance is1.5*(1-damage) per second, with reserve cost
0.5*effort*RS, burst3*effort and strain0.18*effort*SS, where
effort=(1+0.1*load)*resistance. Existing Python layered_body coefficients are used.
Body feasibility and clearance across the entire run segment are checked before
selection and again at execution. Resistance uses that segment's midpoint.

Safety ranks currently feasible away-facing walk/run choices by projected
separation minus0.05*effort*(run ? 5 : 1), rather than always commanding run.
No feasible run leaves walk/scan available. Running is not an ordinary exploration
candidate yet; urgency, learned running preference and safety-method H are future
work. Completed running does not certify safety, fulfill food/home goals, or earn
route support. Each executed run retains bounded source/body delta diagnostics.

`--low-obstacles on` adds three narrow height0.4 barriers at x=-2/0/2,z=4.5,
radius0.15. Default off. `--climbing on` independently enables current feasible
climb candidates; obstacle-on/climb-off is a same-World control. Low barriers are
physical blockers but not food/home/hazard sight blockers in this finite adapter.
This is not general vertical occlusion; other existing contact/communication
geometry retains its conservative physical blocker rule.

Climb distance is1*(1-damage), maximum height0.6*(1-damage)/(1+0.1*load), with
1e-12 height comparison tolerance. Full crossed low-obstacle height, high obstacle
intersection, and clear landing are checked. Burst4*effort, reserve0.4*effort*RS,
strain0.15*effort*SS match the Python body coefficients. Candidate height/effort is
current local evidence; obstacle identities and map centers stay World-side.

Climb methods enter existing food/home BasicLoops only for directions whose walk
candidate is unavailable. Fixed alignment-minus-effort priority competes with
walking/scan; execution is rechecked using current load. Progress may resolve the
climb method's question without resolving food/home goal H. Danger-climbing,
learned climbing preferences and route reinforcement from climb are not added.
Ground priority projection remains walk-only; climb has its own effort term.

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

Running evidence: [finite danger-running report](../../experiments/julia_migration/lw_integrated/running_report.md),
42 checks passed;24 actual runs in a three-day living comparison. Climb/drop remain next.

Climbing evidence: [load-limited climbing report](../../experiments/julia_migration/lw_integrated/climbing_report.md),
43 checks passed; seven actual crossings in the three-day native comparison.
Prior two-seed behavior remains unchanged with low obstacles and climbing off.


Dropped cargo implementation is now present locally, but cloud acceptance is pending.
See [scope and pending verification](../../experiments/julia_migration/lw_integrated/drop_plan.md).
Do not read the unverified implementation as completed LW acceptance.


Drop execution: [report](../../experiments/julia_migration/lw_integrated/drop_report.md),
52 checks passed. Native three-day case selected no drops. Controlled case exposed
4,290 drop/recovery cycles before return time; physical transfer works, parent-purpose
persistence across load changes remains unresolved.


Parent-purpose follow-up: [report](../../experiments/julia_migration/lw_integrated/return_purpose_report.md).
64 checks passed; the same controlled case now drops at60s, climbs at61s and deposits
at62s. B recovers the discarded unit at64s. The previously observed drop/recovery
loop is resolved in this case by retaining return across load changes. General
high-level purpose abandonment is not implemented.


Social response: [finite port report](../../experiments/julia_migration/lw_integrated/social_response_report.md).
39 checks passed. Controlled living run produced three gives/one refusal and a
Sleep-formed expectation of2/3. Prior-refusal response influence remains locally
tested only; general Sleep and food-retention projection are still unported.


General Sleep comparison entrance: [report](../../experiments/julia_migration/lw_integrated/general_sleep_report.md),
45 checks passed. Nine completed reviews:two comparisons and seven insufficient
windows. Behavior unchanged. Automatic adoption/use and richer retained experiences
remain separate unported boundaries.


Sleep action use: [report](../../experiments/julia_migration/lw_integrated/sleep_action_report.md),
41 checks passed. B had5054 real candidate-evaluation applications, zero changed
selections; A/C only rest sources. Full context/action vocabulary and bundle Sleep
remain gaps. This is unvalidated local use, not canonical adoption.


Daytime retention: [report](../../experiments/julia_migration/lw_integrated/sleep_retention_report.md),
38 checks passed. Opt-in32 action/outcome strata preserve daytime records into
Sleep; live three-day run has161 local selection differences, not a general
efficiency claim. Full conjunction bundles/dormancy remain unported.


Sleep maintenance: [report](../../experiments/julia_migration/lw_integrated/sleep_maintenance_report.md),
41 checks passed. Four-day native run produces14 dormant records, no live wake
event, unchanged food/choice counters. Reactivation is verified locally; this is
per-record lifecycle adaptation, not full conjunction-bundle migration.


## Completion gates for the full LW migration (2026-10-13)

The active objective is full major-function LW migration, not completion of each
small experiment in isolation. Current evidence does NOT satisfy this objective.

| Gate | Current evidence / remaining work |
|---|---|
| Native generation through saving | Implemented and frozen-spec replay tested |
| Body and cargo | Local walk/run/climb/drop; basal metabolism and broader body-driven selection still need mapping |
| Sensing and navigation | Beacon/fan only; ground patterns, full landmarks/relative route composition remain |
| Shared World history | Walking wear/recovery verified in three-day living comparison; local appearance and recognized patterns next |
| Danger/social | Finite crossing and request/refusal; territory, fuller safety methods and richer social constraints remain |
| Sleep/model lifecycle | Local adoption/use/replacement/dormancy; full action/context/bundle coverage and live reactivation evidence remain |
| 30 days / multiple seeds | NOT RUN; four-day guard, model/receipt capacity and history costs must be audited before raising it |
| Conservation/parent continuity | Covered in finite runs; must recheck in full-feature long campaign |
| Performance/memory | Local historical measurements only; integrated warmed runtime and peak memory outstanding |
| Backend switch decision | NOT READY; Python remains reference/production path |

Do not certify full parity from isolated fixture success. Preserve explicit local
GameAI versus canonical T1 boundaries. Ground wear is World state; it is neither
agent route memory nor evidence that an agent knows where a path leads.

Ground wear: [report](../../experiments/julia_migration/lw_integrated/ground_wear_report.md),
41 assertions PASS,1248 touched cells/432 road-threshold cells after three days.
Appearance/pattern recognition and30-day full integration remain outstanding.

Ground appearance/patterns: [report](../../experiments/julia_migration/lw_integrated/ground_pattern_report.md),
36 checks PASS. Local15-point ground samples and structural grouping match Python
reference cases. Three-day perception-only comparison preserves all other output.
Ground recovery now uses an absolute last-walk anchor to avoid read-frequency
rounding effects. Body-linked continuity and exploration proposals are next.

Ground continuity: [report](../../experiments/julia_migration/lw_integrated/ground_continuity_report.md),
42 checks PASS. Three-day living run selects ground methods5649 times.
Retired never-reused method nodes are pruned after result resolution, preserving
all saved behavior except obsolete node maps. Full landscape parity remains open.

Food/body: [report](../../experiments/julia_migration/lw_integrated/food_body_report.md),
40 checks PASS. Existing basal metabolism,hunger H,food bands/provisioned rest and
own-food retention in giving now connected. Three-day live comparison conserves
food and completes9 Sleeps; full integrated long-run acceptance remains open.

World hazard: [report](../../experiments/julia_migration/lw_integrated/world_hazard_report.md),
753 assertions PASS, including Python fixed-trajectory comparison and3-day life.
Territory/patrol interact with existing food/body/Sleep. Multi-threat method H
and full warning selection remain unported; attack/damage are not added.
