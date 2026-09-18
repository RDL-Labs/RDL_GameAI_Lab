# Base-Food Assisted Loop Contract

**Status:** Phase 1-8 operational finite experiment
**Boundary:** GameAI-local policy plus Godot-owned world resolution

Completion evidence: [Base-Food Reference Loop Evidence](../experiment-evidence/BASE_FOOD_reference_loop_evidence.md)

## Operational path

Godot owns the precise Base stock, agent position, held Food, and world objects.
It compresses Base stock into a coarse God Statue Food cue and an NPC-observed
stock band. The Runtime receives no precise Base stock value.

    coarse system_assessment cue
    + NPC-observed Base stock band
    + visible Food
    -> NPC short directional prediction
    -> replenish_base_food Goal
    -> GO_TO_SITE
    -> GATHER
    -> RETURN_BASE
    -> DEPOSIT
    -> Godot Base stock recovery

The cue is finite observation material, not an action command. A low cue without
a matching low NPC observation cannot form the Goal. The policy maintains the
current trajectory instead of performing unrestricted candidate reselection.

Each agent has a finite experimental cue disposition: follow or ignore. Ignore
forms no Goal and returns idle. Godot continues Base consumption and FoodNeed
change, so ignored shortage can produce observable empty-stock and worsening-need
evidence without turning the cue into a command.

Successful deposit is reported to POST /v1/life-result and retained as a finite,
idempotent GameAI-local cue-result relation. GET /v1/life-snapshot exposes the
records and habit boundary. Two distinct replenish successes are required before
an NPC may form the same Goal from observed low stock with no God Statue cue.
One success is insufficient. Cue-free completion uses the learned relation but
does not manufacture another cue-result record.

Phase 6 adds a finite generic interrupt comparison. `life_context` may contain
generic candidates with unique IDs and salience in `[0, 1]`. A candidate at or
above the fixed `0.7` threshold holds an existing committed trajectory and
reports `SUSPENDED`; it does not erase the Goal or choose another world action.
When the candidate disappears, the retained trajectory resumes from current
world state. Sub-threshold candidates do not interrupt it.

Phase 7 admits `threat` candidates through the same bounded observation field.
Fixed NPC-side profiles provide finite thresholds: `cautious=0.4`,
`standard=0.7`, and `steadfast=0.9`. Thus the same Threat candidate and same
world state can hold or preserve a trajectory according to the configured NPC
profile. The profile changes only this comparison; it is not a diagnosis,
emotion, dynamic neural value, or Threat-issued command.

Phase 8 admits `novelty` candidates only when `target_id` names an object in
the current bounded observation. Fixed NPC-side responses are `ignore`,
`inspect`, and `divert`. Ignore continues the existing Base-Food action;
inspect reports `SUSPENDED` and emits idle; divert reports `SUSPENDED` and uses
the existing approach action toward the novelty target. Inspect and divert keep
the original Goal/Trajectory, which resumes from current world state after the
candidate disappears.

The post-Phase-8 tuning step provides two extreme operational presets.
`trajectory_locked` uses `0.95` generic/Threat/Novelty thresholds with Novelty
ignore; `context_switching` uses `0.25` thresholds with Novelty divert. The
presets expose useful tuning bounds under equal observations. They are mutually
exclusive with per-axis Threat/Novelty settings for the same agent and are not
personality, diagnosis, DNA, dynamic neural state, affect, canonical M_B, or H.

## Authority

- Godot owns and resolves World truth.
- BaseFoodLifePolicy owns only the opt-in GameAI-local Goal/Trajectory state.
- The policy has no canonical M_B, H, T1, graph mutation, or canonical action authority.
- The God Statue system assessment is distinct from future Player utterances.
- Existing default Runtime, history influence, and FoodNeed shadow paths remain unchanged.

## Running

    python -m runtime.bridge --base-food-life

An explicit ignore case can be started with:

    python -m runtime.bridge --base-food-life --base-food-cue-response npc_b=ignore

Open the Workbench, select Runtime mode, and select an NPC. The Inspector and
Decision Record show the coarse cue, short prediction, Goal, phase, and deposit effect.

## Deferred

The following v0.3 stages are not operational yet:

- dynamic/derived interrupt thresholds and learned Novelty dispositions
- D3/D4-like axes, personality claims, and neural/DNA derivation
- Player-authored Statue utterances
