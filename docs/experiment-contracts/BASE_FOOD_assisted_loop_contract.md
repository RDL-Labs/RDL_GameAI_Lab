# Base-Food Assisted Loop Contract

**Status:** Phase 1-4 operational finite experiment
**Boundary:** GameAI-local policy plus Godot-owned world resolution

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

- cue-result experience relation
- habit strengthening or cue dependency reduction
- cue-independent Goal formation
- generic, Threat, or Novelty interruption
- Player-authored Statue utterances
