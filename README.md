# RDL Game AI Lab

`RDL_GameAI_Lab` is an experimental playground for building **interesting game AI rather than merely strong game AI**.

> **世界・他者・自身の履歴との相互作用によって、理解可能だが固定されない振る舞いを生むAIを検証する。**

`RDL_Demos`、`RDL_Enterprise`、`RDL_Human` は素材鉱山として扱い、Core意味論は現行 `RDL_Core` T0/T1 v2.3 と分離して参照する。

## Start here

- [Overall GameAI design map](docs/design/RDL_GameAI_全体設計地図.md)
- [Core v2.3 semantic reference](docs/semantic-reference/RDL_Core_T0_T1_reference.md)
- [Current experiment roadmap](notes/experiment-roadmap.md)
- [NPC layer-based design plan](docs/design/RDL_GameAI_NPC_レイヤー別設計計画.md)
- [Neural parameter blueprint](docs/design/RDL_GameAI_神経パラメーター設計図.md)
- [Sleep / consolidation design](docs/design/RDL_GameAI_睡眠システム設計.md)
- [Affect / history / relational constraint model](docs/design/RDL_GameAI_感情・履歴・関係拘束モデル.md)
- [GameAI design method](docs/design/RDL_GameAI_設計手法.md)

## Four separate planning views

GameAI Lab now keeps four kinds of design apart.

```text
A. Canonical / RDL maturity
B. NPC internal layer profile
C. Game feature roadmap
D. Cross-cutting systems
```

```text
canonical maturity
!= NPC internal structure
!= game-feature implementation order
!= sleep / communication / time update cycle
```

See the [overall design map](docs/design/RDL_GameAI_全体設計地図.md) for their connections.

## Current semantic boundary

```text
SILN participates in one or more RIBs
Purpose / finite B selects RIB_B
Engine world state != Agent Observation != RIB_B != Agent M_B
F / F' use the same frozen pre-update M_B
E = Δ(F,F')
nonzero E != unresolved by definition
only finite-reviewed unresolved remainder may enter H
H != fear / fun / jealousy / stress / Human Attention
Structural Conflict != E != H
∀B_finite: ξ(B) != 0
ξ != runtime uncertainty / coverage / novelty / exploration scalar
```

GameAI-local Body / Experience / Neural / Current Context conditions are not Core primitives merely because they influence behavior.

## NPC layering profile

```text
Generation / DNA
      ↓
Neural Dynamics
      ↓
Physical / Body
      ↓
Experience / Relation History
      ↓
Realtime / Current Context
```

This is an organization and testing view, not a canonical `M_B` decomposition.

### Generation / DNA

DNA is modeled as a baseline generator rather than a personality label.

```text
DNA
→ neural parameter μ / σ
→ body / sensory possibility ranges
```

Runtime reproduction / evolution remains deferred.

### Neural Dynamics

The design keeps fine-grained operational labels available:

```text
DA: D1 / D2 / D3 / D4
5-HT: 5-HT1 / 5-HT2 / 5-HT3 / 5-HT4
OXT
NA: α1 / α2 / β
```

These bias attention, action, repetition, relation persistence, alerting and recovery; they are not direct behavior commands or Core primitives.

## Current operational slices

The canonical path is still read-only with respect to action / graph mutation, but the runtime now has several bounded GameAI-local and diagnostic slices around it.

Canonical observation / interpretation path:

```text
bounded observation
→ Purpose / finite B / selected dimensions / conditions / coverage / provenance
→ RIB_B
→ same frozen pre-update M_B
→ F / F'
→ E
→ explicit finite review
→ diagnostic H only for reviewed unresolved residual
```

Experience / Body / response-profile slices are kept separate from canonical authority.

Current implemented bounded experiments include:

```text
finite E review / unresolved residual / retained H
finite InteractionHistory for admitted approach outcomes
opt-in history-based retry influence
fixed per-agent retry sensitivity profiles
bounded body movement capability and recovery checks
derived display-only response expression
```

See [notes/experiment-roadmap.md](notes/experiment-roadmap.md) and the experiment contracts for exact acceptance boundaries.

## Cross-cutting systems

### Sleep / consolidation

Sleep is not a sixth NPC layer.

```text
Sleep
├ Body Recovery
└ Experience Consolidation
```

The design allows forgetting, compression, generalization and even semantically wrong associations, while retaining structural provenance.

### Communication / vocabulary

Communication is treated as finite interaction rather than truth transfer.

```text
speaker state
→ CommunicativeIntent
→ Expression
→ listener observes
→ listener interprets under its own finite relation structure
→ response
```

A communicated meaning is not copied directly into another NPC and is not automatically world truth.

### Player interface

The provisional player role is a fixed talking statue / oracle-like object in the home area. The main early intervention is vocabulary supply and naming rather than direct NPC control. Player statements remain ordinary observed information from the NPC perspective.

### World time

World time connects daily routine, food, fatigue, sleep, safe return, absence detection and later search/rescue behavior.

## Game concept direction

The current game direction is:

> **かわいい生き物が、食料・休息・身体・安全・経験・仲間との関係に拘束されながら、小さな世界で失敗し、助け合い、休み、回復しながら必死に暮らす。**

The first life-system development line is:

```text
Food
→ Rest / Sleep
→ EnergyReserve / ActiveEnergy
→ Safety / Danger
→ Incapacitation / Injury
→ Rescue / Recovery
→ Hunting
```

Later:

```text
Materials
→ Tools
→ Crafting
→ Barter
→ Emergent Value
```

These game-feature phases do not override the canonical roadmap.

## Semantic fallibility

GameAI deliberately allows semantic/cognitive error while preserving structural integrity.

```text
semantic fallibility allowed
structural integrity required
```

Allowed examples:

```text
misrecognition
wrong naming
over-generalization
biased relation formation
odd sleep association
rumor / misunderstanding
```

Not allowed as intentional behavior:

```text
broken IDs
lost provenance
invalid references
silent canonical mutation
```

The aim is to observe how mistakes form, propagate, break and repair.

## Source mines

### RDL_Demos

Use as an implementation and finite-operation source where its semantics are compatible with current Core boundaries.

### RDL_Enterprise

Use bounded acquisition, provenance, explicit selection/revision, authority separation and durable trace patterns as implementation material. Enterprise's conservative error handling is not automatically required for GameAI semantic cognition.

### RDL_Human

Use as a hypothesis mine for neural dynamics, affect, relation and temporal behavior. Human-specific labels remain application-level hypotheses unless separately adopted by GameAI.

### RDL_General_Modules

Use the current horizontal layering kit as an organization aid. It does not confer runtime or canonical authority.

## Runtime

```bash
python -m runtime.bridge
```

Key endpoints currently include observation, canonical snapshot, assessment review, interaction-result and experience-snapshot paths. Exact runtime behavior is governed by the current experiment contracts.

## Next boundaries

Near-term work now splits into two independent lines.

Canonical maturity:

```text
current reviewed E/H + bounded local influences
→ richer relation history / neural influence
→ M_Δ / T1 reconstruction
→ finite-context authority / fresh re-entry
```

Game-world vertical development:

```text
Food / Rest / Energy
→ Safety / Injury / Rescue
→ Hunting
```

Cross-cutting systems such as World Time, Sleep Consolidation and Communication should be attached where their minimum vertical experiments become testable rather than forced into the canonical sequence.

## Tests

```bash
python -m unittest discover -s tests -v
```

A green test means only that no contract violation was observed inside the declared finite test Boundary.

```text
current finite Boundaryで operationally sufficient
!= terminally complete
!= universally valid
!= all game behavior evaluated
```

## Repository shape

```text
docs/
  semantic-reference/   current Core reading
  source-inventory/     source-mine evaluations
  design/               GameAI design documents
  experiment-contracts/ runtime acceptance contracts
  experiment-evidence/  runtime evidence
runtime/                 action runtime + read-only canonical sidecar
godot/                   bounded world / interaction workbench
experiments/             small runnable prototypes
notes/                   forward canonical roadmap
tests/                   Python acceptance tests
```
