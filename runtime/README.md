# RDL GameAI Runtime

Action responses include `inspection.expression`, a pure derived response label
with body/profile/history provenance. See the [expression contract](../docs/experiment-contracts/EXPRESSION_response_contract.md).

Optional `observation.body` snapshots constrain approach eligibility; stopped
agents idle even under history influence. Godot controls actual displacement.
See the [Body contract](../docs/experiment-contracts/BODY_movement_contract.md).

The [opt-in minimal Rest slice](../docs/experiment-contracts/REST_minimal_loop_contract.md)
accepts bounded `rest_need` and a visible rest-capable place, then emits
`approach`, `rest`, or `idle`. Godot owns RestNeed, reachability, and recovery.
Food and Rest remain isolated by default. Their first explicit integration is
enabled with `python -m runtime.bridge --food-rest-life`; the
[finite coordinator contract](../docs/experiment-contracts/FOOD_REST_continuous_life_contract.md)
temporarily prefers Rest at the fixed experiment threshold, then re-evaluates
the retained Food trajectory from the current packet. This is not general Need
arbitration.

`python -m runtime.bridge --rest-trajectory` enables the isolated
[Rest Goal / Trajectory policy](../docs/experiment-contracts/REST_trajectory_contract.md).
It keeps one fixed rest target through generic interruption and releases it on
observed recovery or target disappearance. Observed safety is not yet used for
selection.

`python -m runtime.bridge --safety-trajectory` enables the isolated Safety
escape trajectory through the normal bridge startup path. It cannot be combined
with Base-Food, Rest, or history-influence action policies in this phase.

Add `--rest-rho-candidates` with `--rest-trajectory` to enable the
[ρ Rest candidate-description experiment](../docs/experiment-contracts/RHO_rest_candidate_description_contract.md).
ρ changes only the bounded candidate fields passed to the unchanged selector;
it does not select or commit the target directly.

Individual retry experiment: `python -m runtime.bridge --history-influence --retry-profile npc_a=long --retry-profile npc_b=short`.
The [profile contract](../docs/experiment-contracts/SENSITIVITY_retry_profile_contract.md) defines fixed 1/3/5 tick response tendencies and their finite limits.

Optional history-to-action experiment: `python -m runtime.bridge --history-influence`.
This enables the [finite retry-window policy](../docs/experiment-contracts/EXPERIENCE_influence_contract.md).
Default startup retains the existing policy. The experimental decision cache
is limited to 128 observations per process and requires a fresh runtime afterward.

The [Experience history API](../docs/experiment-contracts/EXPERIENCE_history_contract.md) accepts `POST /v1/interaction-result` for admitted approach decisions and exposes `GET /v1/experience-snapshot`. Godot reports bounded outcomes automatically in Runtime mode. Storage is read-only with respect to action and canonical semantics.

`SleepExperienceWindowStore` implements the opt-in S1 source boundary described
by the [finite Sleep Experience window contract](../docs/experiment-contracts/SLEEP_experience_window_contract.md).
It freezes three to six accepted same-agent Experience references per sleep
cycle without changing raw history or forming a relation candidate.

S2 and S3 continue through explicit code levels: `runtime/structural` owns I1
finite relation construction/alignment, `runtime/functions` owns pure Profile
and Deep Similarity functions, and `runtime/mechanisms/DeepSimilarityShadowStore`
owns opt-in immutable replay. The resulting candidate is a local shadow object;
it has no decision, `E`, `H`, `theta_eff`, `M_delta`, canonical `M_B`, or T1
authority.

`python -m runtime.bridge --sleep-consolidation` enables the opt-in
[S4 vertical](../docs/experiment-contracts/SLEEP_consolidation_vertical_contract.md).
An explicit Godot cycle freezes the daytime S1 window before Sleep transit,
then a correlated safe Sleep result runs S2/S3 and exposes the shadow through
`GET /v1/sleep-consolidation-snapshot`. Default Sleep still performs body
recovery only and reports `consolidation=not_run`.

`python -m runtime.bridge --fast-retrieval` enables the opt-in
[F1 Activity Fast Retrieval](../docs/experiment-contracts/FAST_activity_retrieval_contract.md).
Each accepted approach result derives a current Profile, performs bounded L0
signature overlap and L1 comparison against typed raw/Sleep sources, and stores
at most three matches. `GET /v1/fast-retrieval-snapshot` is read-only; the
result cannot change an action or form a new candidate.

Finite assessment is available at `POST /v1/assessment-review`; inspect IDs and revisions through `GET /v1/canonical-snapshot`. See [the current contract](../docs/experiment-contracts/CURRENT_v23_runtime_contract.md#finite-assessment-api) for request format, provenance, residual bounds, and retention. Diagnostic H is available per comparison and as retained residuals per exact context/frozen model.

The same canonical snapshot includes the read-only
[C2 Review Path projection](../docs/experiment-contracts/CANONICAL_review_path_projection_contract.md).

C3 adds a finite, independently sourced `theta_eff` evaluation and read-only
`H < theta_eff` / `H >= theta_eff` comparison. A met rupture boundary does not
enter `M_delta` by itself. C4 performs that finite transition only while an
explicit review is accepted; GET snapshots remain read-only. Active `M_delta`
is retained until future explicit T1 resolution.

T1-A can explicitly freeze an immutable material bundle for an active
`M_delta`: current frozen `M_B`, the RIB pair, transition-time unresolved
residual, and bounded same-agent candidates/Experience. Every item remains
`UNINSPECTED`; T1-A自身はselectionを持たず、T1-C reconstructionも行わない。

T1-B accepts a complete explicit review of one immutable bundle and records
`RETAIN`, `REJECT`, or `DEFER` with per-material basis/evidence and a revision
guard. `RETAIN` is not adoption: the bundle and old `M_B` remain unchanged, and
only the later T1-C step may construct a separate artifact.

T1-C reconstructs a distinct inactive `M_B'` artifact only when the parent
model and at least one CandidateRelation are explicitly retained. It preserves
the old model, adopts only retained candidate signatures, and does not perform
authority cutover or re-entry.
Each admitted assessment retains its exact `RIB_B/F/RIB_B'/F'/E` pair and joins
the latest explicit review revision and H. Local Experience, Sleep candidates,
and Fast retrieval are excluded from this projection.

This is the minimal Python-side runtime boundary for the Godot workbench.

The assisted Base-Food experiment is opt-in with
python -m runtime.bridge --base-food-life.

It consumes only the coarse God Statue cue, NPC-observed stock band, known Base
relation, bounded visible Food, and self-body snapshot. It maintains a finite
GameAI-local Goal/Trajectory through deposit. It does not admit precise Base
stock or add canonical action authority. Its finite two-success habit boundary
does not implement a general learning system.

Phase 4 follow/ignore evidence is configurable per agent:

    python -m runtime.bridge --base-food-life --base-food-cue-response npc_b=ignore

This fixed experimental disposition belongs to the NPC-side policy. It is not
encoded in the God Statue cue and does not modify canonical M_B or H.

Successful assisted deposits are accepted at POST /v1/life-result and inspected
through GET /v1/life-snapshot. Records are finite and idempotent. Two distinct
successes enable the cue-independent low-stock trigger for that agent; one does
not. This is GameAI-local habit evidence, not canonical M_B admission.

Phase 6 accepts finite `generic` interrupt candidates in `life_context`. A
candidate at or above the fixed 0.7 salience threshold holds the committed
trajectory as `SUSPENDED`; removing it resumes the prior Base-Food path. The
candidate is observation material, not action authority. Threat and Novelty
interpretation are separate later phases.

Phase 7 adds fixed NPC-side Threat profiles:

    python -m runtime.bridge --base-food-life --base-food-threat-profile npc_b=cautious

`cautious / standard / steadfast` map to finite thresholds `0.4 / 0.7 / 0.9`.
The same bounded Threat candidate may therefore hold one NPC's trajectory while
another continues. These profiles are fixed experiment configuration, not a
diagnosis, dynamic neural state, affect, canonical M_B, or H.

Phase 8 adds fixed NPC-side Novelty responses:

    python -m runtime.bridge --base-food-life --base-food-novelty-response npc_b=divert

The response is one of `ignore / inspect / divert`. Novelty must identify an
object inside the current bounded observation. Ignore preserves the current
Base-Food action, inspect holds it with no world action, and divert uses the
existing approach action toward the visible novelty. Inspect/divert retain the
original trajectory and it resumes after the candidate disappears. This is not
general curiosity learning or a canonical model update.

The final v0.3 tuning slice bundles the interrupt axes into two deliberately
extreme operational presets:

    python -m runtime.bridge --base-food-life --base-food-extreme-profile npc_b=trajectory_locked

`trajectory_locked` uses `0.95` generic/Threat/Novelty thresholds and ignores
Novelty. `context_switching` uses `0.25` thresholds and diverts toward visible
Novelty. A preset cannot be combined with per-axis Threat/Novelty settings for
the same agent. These are tuning bounds, not personalities, diagnoses, DNA,
dynamic neural state, affect, canonical M_B, or H.

Current properties:

- localhost HTTP only
- Python standard library only
- bounded observation packet in
- structured action JSON out
- existing action policy unchanged
- read-only Core v2.3 canonical sidecar attached after accepted decisions
- canonical path currently reaches `RIB_B -> frozen M_B -> F/F' -> E`
- explicit diagnostic residual review, per-comparison H, retained H, finite theta_eff comparison, and explicit normal/M_Δ phase transition by finite context/model; no time decay, T1 material processing/reconstruction, re-entry, or canonical authority cutover yet

## Run

```bash
python -m runtime.bridge
```

```text
POST http://127.0.0.1:8765/v1/observe
GET  http://127.0.0.1:8765/health
GET  http://127.0.0.1:8765/v1/canonical-snapshot
```

## Existing action path

The runtime still selects an action from the accepted bounded observation. The canonical sidecar cannot modify that response.

```text
bounded observation
-> existing decide_action()
-> structured action response
```

The Godot workbench resolves the action, changes mock-world conditions, and generates a later bounded observation.

## Canonical acquisition

The raw observation packet is not canonical `RIB_B` by identity.

```text
accepted bounded observation
-> Purpose / finite B
   + selected dimensions
   + conditions
   + coverage
   + provenance
-> RIB_B
```

Current selected GameAI-local dimensions:

```text
visible_agents_count
visible_objects_count
visible_places_count
```

Missing selected coverage is not converted to zero.

## Frozen M_B / F / F' / E

FoodNeed admission PR 1-2 remains default-off and offline. `v23_food_admission.py` can validate
an explicit body snapshot and form an immutable
`food_need -> visible_food_salience` relation with deterministic identity.
`visible_food_count` is available only through an explicit custom Boundary;
an explicit single-use shadow window can then form F/F'/E with the same frozen
FoodNeed. The default Boundary, global sidecar, bridge, assessment, and action
path do not use it. See the [shadow contract](../docs/experiment-contracts/FOOD_NEED_MB_shadow_contract.md).

Enable the controlled exposure explicitly:

```powershell
python -m runtime.bridge --food-mb-shadow
```

The flag is accepted only with a loopback host. It enables:

```text
POST /v1/food-mb-shadow/open
POST /v1/food-mb-shadow/compare
GET  /v1/food-mb-shadow
```

Without the flag these paths return 404. They use a server-instance shadow
sidecar and never register models or E in `GET /v1/canonical-snapshot`.

For each exact finite context, the read-only sidecar creates one immutable diagnostic evaluator:

```text
agent
+ boundary id
+ Purpose
+ selected dimensions
+ conditions
-> frozen model_ref
```

The first model is intentionally simple: identity projection over the selected count dimensions. This is a finite experiment model, not a Core constant and not action authority.

```text
RIB_B(t)
-> same frozen pre-update M_B
-> F(t)

RIB_B(t+Δ)
-> same frozen pre-update M_B
-> F'(t+Δ)
-> E = Δ(F,F')
```

A change in finite context opens a different model/window. No E is formed across different contexts or different model refs.

The current E record remains:

```text
status = E-only-not-reviewed
```

It is not automatically unresolved and is not H.

## Snapshot

`GET /v1/canonical-snapshot` reports:

```text
authority = read-only-comparison-sidecar
stage = RIB_B-frozen-M_B-F-F_prime-E
latest RIB_B sections
finite diagnostic M_B records
latest interpretations
latest E records
xi_status = unrecovered-relations-remain
```

Core ξ remains qualitative; no runtime scalar is assigned to it.

## Current stop rule

The comparison path retains raw E; a separate explicit assessment forms per-comparison residual H.

```text
implemented:
Observation -> RIB_B -> frozen M_B -> F/F' -> E

not implemented:
time decay / θ
M_Δ
T1
canonical authority cutover
```

Finite assessment requires explicit reviewer, basis, and evidence. Nonzero E alone is insufficient for H. Snapshot `assessment.retained_H` sums the latest reviewed residuals per dimension within each exact context/model, then takes local L2. Re-review replaces a contribution; explicit resolution removes it. There is no time decay, signed cancellation, cross-context total, or restart persistence. The contract specifies retention limits and repeated-event accounting.
