# Julia LW backend decision

Date: 2026-10-14. Runtime revision:72ff1d5. Decision: READY for standalone LW experiments under the declared adapters.
The requested major-function migration is complete; this is not full Python runtime parity.

## Scope and reference

The requested migration is the major functions of Python's standalone LW
(integrations/lightweight/integrated_social_campaign.py -> timed_harvest.run),
including later connected body, experience, ground and selection adapters.
It is not a replacement of every Python runtime or Luanti/HTTP/Godot integration.
Behavioral fidelity, finite observation and conserved effects are the contract;
identical Python command streams are explicitly not required.

## Requirement evidence

| Requirement | Implementation / inspected evidence |
|---|---|
| Julia-only World to saved results | native.jl,world.jl,run_integrated,lw_day; Julia-only cloud workflows and stable integrations/lightweight_julia/run.jl replay |
| Major function correspondence | RDL_Julia_LW_Integration_Status.md current matrix and per-module reports; goal threshold12, lateral113+13+30 checks |
| Unified living World | compatible full configuration in long_run_checks.jl; body, observation, goals, methods, social, Sleep, routes, ground and hazards share one loop |
|30 days, multiple seeds, reproducibility| cloud38376126204 and38423218244, seeds04/05, exact frozen replay; independent audit_result and audit_directory |
| Food and cargo conservation | per-operation invariant, daily/terminal audits, drop/recovery ownership fixture and inherited cargo checks |
| Learn/use/invalidate/relearn | B1g renewal report and harvest_review/relearn; supplied finite schemas, not canonical T1 |
| Sleep dormancy and reactivation |30-day Sleep-model wake3 for seed04 B; bundle waking87/71; applications and selection changes preserved by optimization |
| Parent objective continuity | return_purpose.jl, drop_checks.jl first drop through deposit retains home and excludes pickup/recovery; day transition and empty load tested |
| Performance and memory | optimized_long_report.md: first calls1519.862/1084.617s, allocated361.993/348.016GB, peakRSS1.383/1.546GB; no claim of whole Python speed ratio |
| Preserved semantic boundaries | GameAI-local H, purpose and candidate schemas; no claim of canonical T1/M_B reconstruction or hidden World access |

The optimized30-day revision966949d precedes optional threshold/handedness
connections. Those default to legacy behavior, verified by saved output equality,
and have separate shorter living checks. Not every optional configuration has
been tested for30 days; mutually exclusive trails/bundle-credit are not combined.

## Declared differences and unimplemented areas

- Native combined heading/step and one-second schedule replace separate Python
  turn/move and configurable observation cadence. Seeds use Julia RNG; reuse
  frozen specs for identical Worlds.
- Native local home sensing exposes relative distance and finite color routes.
  It does not give a global map; route and learned-model vocabularies are finite.
- Lateral eligibility uses component checks and finite observed rays, projecting
  a bounded delta into native priorities. It does not replace native steering
  with the Python terrain-minimum controller. See lateral_report.md.
- General Sleep changes priorities of existing candidates; it does not invent
  unrestricted actions. Positive parent-credit reinforcement has local tests;
  its older living fixture did not exhibit it. This limits the empirical claim,
  not the connection's existence. Bundle credit and trails are exclusive modes.
- Environmental checkpoints support a new cohort. Arbitrary same-agent process
  continuation is not implemented. This is distinct from frozen-input replay.
- Biological fidelity, new arbitrary candidate invention, canonical T1, separate
  experimental rest reactivation, Luanti/HTTP and Godot transport are not claimed.
- Windows access violations remain unexplained. Successful local runs do not
  prove repair. Linux cloud is the reproducible long-run execution environment.

## Operation and switching

Use integrations/lightweight_julia/run.jl with the locked Julia environment and
saved accepted spec for composed experiments. The small default CLI is not the
full feature campaign. Keep all four files:spec,manifest,result,summary.
Python remains the reference and an available fallback. Do not overwrite old
Python evidence or reinterpret its timings as comparable full-LW measurements.

This decision evaluates code/behavior, not deployment. Main on GitHub is not
updated by this document. Local modifications must be published through the
repository's authorized workflow. Generic kernel/specialized-layer restructuring
is a separate subsequent project, not hidden in the migration acceptance.


## Final local regression and repeatable commands

On revision72ff1d5 the entire drop_checks.jl completed with exit0:71 assertions,
including two three-day drop off/on campaigns and the controlled one-day
home-purpose sequence. Stable entry replay also matched and passed the independent
51,840-operation audit. No Python executable is invoked by the Julia entry.

From repository root, after the setup command in integrations/lightweight_julia/README.md:

```sh
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/lateral_checks.jl
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/lateral_connection_checks.jl
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/goal_threshold_checks.jl outputs/threshold-check
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/drop_checks.jl outputs/drop-check
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/long_run_checks.jl outputs/long-04 20261004
julia --project=experiments/julia_migration/julia experiments/julia_migration/lw_integrated/long_run_checks.jl outputs/long-05 20261005
```

Long checks default to30 days and include frozen replay; LW_DAYS=3 selects the
short counterpart. For compound right-side checking, run lateral_life_checks.jl
with an output directory and a saved full-campaign spec.json. Raw final local
log:outputs/lw-optimization/final-drop-check.log. Local checks are not a claim
that the entire unrelated Python/Godot suite was rerun on this revision.
