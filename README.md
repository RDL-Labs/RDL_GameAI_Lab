# RDL Game AI Lab

`RDL_GameAI_Lab` is an experimental playground for building **interesting game AI rather than merely strong game AI**.

The target is behavior that becomes understandable through history and relationships without becoming completely fixed or predictable.

> **世界・他者・自身の履歴との相互作用によって、理解可能だが固定されない振る舞いを生むAIを検証する。**

This repository treats `RDL_Enterprise`, `RDL_Demos`, and `RDL_Human` as source mines. Their implementations and hypotheses are working material, not semantic authority. Canonical semantics are checked against `Aporapeiron/RDL_Core` T0/T1.

## Semantic Baseline

- [RDL_Core T0/T1 semantic reference](docs/semantic-reference/RDL_Core_T0_T1_reference.md)
- [Game AI design method draft](docs/design/RDL_GameAI_設計手法_DRAFT_v0.1.md)

Core invariants currently used by the lab:

```text
interaction is foundational
EFP = bounded action-section from interaction
F / F' use the same pre-update M_B
E = discrepancy between interpreted / predicted states
H = unresolved residual of E
H != fear / fun / jealousy / stress
Structural Conflict != E != H
Human Attention load != H
∀B_finite: ξ(B) != 0
```

Engine world state may be used as a simulation reference, but:

```text
Engine world state / simulation reference
!= Agent Observation
!= Agent EFP
!= Agent M_B
```

Enterprise boundary note:

```text
static structural conflict
!= E
!= H
```

A structural conflict becomes relevant to `E -> H` only through an actual interaction chain: action / response changes later interaction conditions, the subsequent `EFP'` is interpreted with the same pre-update `M_B`, and only unresolved residual enters `H`. Human Attention is not system `H`; early Godot experiments keep Human Attention out of scope.

## Design Method

The lab follows a vertical-slice and bounded-acceptance discipline adapted from `RDL_Enterprise`.

```text
T0
  semantic invariants

T1
  Probe → Expansion → Inspection → Selection → Reconstruction

Enterprise design discipline
  finite Boundary
  provenance
  staged commitment
  shallow normal path
  acceptance evidence
  stop rule

GameAI
  sensors / body / world interface
  interestingness-oriented Selection criteria
  experiments
```

New concepts, state variables, or gates are added only when they are needed to inspect an observed break, recover missing provenance, or test an explicit GameAI question.

## Experiment Themes

1. **Interaction-grounded NPC behavior**
   - Build from bounded perception rather than omniscient engine state.
   - Let actions change the conditions generating later `EFP'`.
   - Preserve the same pre-update `M_B` when comparing `F / F'`.

2. **History, relation, and affect expression**
   - Do not use `HState` as a direct mood meter.
   - Treat `H` as unresolved inconsistency.
   - Derive visible affect from heat provenance, relation history, individual sensitivity, body state, and current context.

3. **Learning without policy collapse**
   - Use T1-style `Probe → Expansion → Inspection → Selection → Reconstruction`.
   - Allow contextual coexistence instead of globally overwriting old structures.
   - Use canary / shadow / replay only when an actual experiment requires them.

4. **Living-world simulation**
   - Reuse `rdl_village` and related demos for body, perception, relations, dialogue, and environment.
   - Keep agent knowledge distinct from engine-side reference state.

5. **Richness metrics**
   - Avoid optimizing only for survival or win rate.
   - Observe behavior variety, individual divergence, history dependence, relation dependence, place meaning drift, readability, surprise, and rupture diversity as separate bounded dimensions.

6. **Browser-sized demos**
   - Prefer small inspectable experiments before integrated worlds.
   - Keep each demo focused on one mechanism unless integration itself is the experiment.

## Source Inventory

- [RDL_Enterprise game AI parts](docs/source-inventory/RDL_Enterprise_ゲームAI転用パーツ一覧.md)
- [RDL_Demos game AI inventory](docs/source-inventory/RDL_Demos_ゲームAI素材棚卸し.md)
- [RDL_Human game AI inventory](docs/source-inventory/RDL_Human_ゲームAI素材棚卸し.md)

## Design Documents

- [Animal Crossing style village simulator design](docs/design/RDLどうぶつの森風村シミュレーター設計文書.md)
- [Affect, history, and relational constraint model draft](docs/design/RDL_GameAI_感情・履歴・関係拘束モデル_DRAFT_v0.1.md)
- [Game AI design method draft](docs/design/RDL_GameAI_設計手法_DRAFT_v0.1.md)

## Current First Acceptance Boundary

The first integrated experiment should remain small enough to inspect:

```text
NPC: 3
places: about 4
food: 1 resource family
bounded perception
directional relations
simple body state
relation history
sensitivity profile
one-day cycle
simple player talk / gift / consultation
seeded simulation
replay log
```

Initially deferred:

```text
death
reproduction
complex economy
advanced LLM dialogue
culture generation
full canary / shadow stack
large-scale learning
Human Attention workflow
```

First experiential question:

> **同じNPCを数日眺めたとき、「こいつ昨日のこと引きずってるな」と感じられるか。**

## Experiment Roadmap

See [Experiment Roadmap](notes/experiment-roadmap.md).

Next implementation boundary:

- [P1 Bounded Perception Contract](docs/experiment-contracts/P1_bounded_perception_contract.md)
- [P1 Bounded Perception Evidence](docs/experiment-evidence/P1_bounded_perception_evidence.md)
- [Runtime Bridge](runtime/README.md)

Current bridge stop rule:

```text
Godot bounded observation
→ localhost JSON bridge
→ Python Runtime structured action
```

This does not yet apply actions back into the world and does not implement
`EFP`, `M_B`, `F`, `F'`, `E`, `H`, or Human Attention.

The lab uses acceptance evidence rather than feature-count completion. A green test or deterministic replay means only that no contract violation was observed inside the declared finite test Boundary.

```text
current finite Boundaryで operationally sufficient
!= terminally complete
!= universally valid
!= all game behavior evaluated
```

## Repository Shape

```text
docs/
  semantic-reference/   Canonical T0/T1 references used by the lab
  source-inventory/     Working-material inventories from source projects
  design/               GameAI-specific design drafts
  experiment-contracts/ Bounded acceptance contracts for staged experiments
  experiment-evidence/  Evidence notes for current experiment acceptance
experiments/            Small runnable prototypes
notes/                  Experiment roadmaps and logs
```
