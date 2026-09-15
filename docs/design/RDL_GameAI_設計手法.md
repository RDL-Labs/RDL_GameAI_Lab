# RDL_GameAI 設計手法

*CURRENT — Core v2.3 / RIB_B準拠*

## 0. 目的

`RDL_GameAI_Lab` は、`RDL_Demos`、`RDL_Enterprise`、`RDL_Human` を素材鉱山として使いながら、意味論は `Aporapeiron/RDL_Core` T0/T1 v2.3 を基準に再検査する。

既存実装のクラス名・変数名・過去語彙は、それだけではCore意味を保証しない。本設計手法自身も有限Boundary上の運用方針であり、自己例外化しない。

## 1. 権威順序

```text
RDL_Core v2.3
  T0 BASE / SPEC
  T1 SILN operations
      ↓ semantic / operational authority

RDL_Demos / RDL_Enterprise / RDL_Human
      ↓ extraction / translation

RDL_GameAI_Lab
  game-specific Purpose / B
  acquisition
  Selection criteria
  experiments
  implementations
```

## 2. 現行最低意味境界

```text
nonlinear relational network
      ↕
    SILN
  ↕ {RIB_i}
      ↓ Purpose / finite B
    RIB_B
```

```text
Engine world state
!= Agent bounded observation
!= RIB_B
!= Agent M_B
```

bounded observation は acquisition の raw material であり、canonical `RIB_B` とは同一視しない。

```text
bounded observation
→ Purpose / B / selected dimensions / conditions / coverage / provenance
→ RIB_B
```

selected coverage が欠ける場合、欠測を `0` に変換して section を成立させない。

## 3. 現行comparison path

```text
RIB_B(t)
↓ same frozen pre-update M_B
F(t)

RIB_B(t+Δ)
↓ same frozen pre-update M_B
F'(t+Δ)
↓
E = Δ(F,F')
```

`E` は engine truth と agent表象の誤差ではない。比較途中で `M_B` を更新しない。boundary / selected coverage / model_ref が変われば同じcomparison windowとして扱わない。

現在のP4 evaluatorは、選択count dimension上の有限なdiagnostic identity projectionである。Core定数でも行動authorityでもない。

## 4. EとHを分ける

```text
E
↓ finite assessment
zero / pending / resolved / ordinary temporal change /
boundary or coverage change / unresolved
↓ unresolved only
H_vec
↓
H = ||H_vec||
```

非ゼロEの大きさだけで unresolved と判定しない。

```text
H != fear
H != fun
H != anger
H != jealousy
H != stress
H != Human Attention load
```

## 5. ξ

```text
∀B_finite: ξ(B) != 0
```

`ξ` を novelty、unknown count、coverage gap、uncertainty score、探索圧、stressなどのruntime scalarへ潰さない。

## 6. T1

```text
H >= θ
→ M_Δ
→ current M_B becomes SILN_SELF
→ Probe
→ Expansion
→ Inspection
→ Selection
→ Reconstruction
→ M_B'
→ fresh re-entry validation
```

`H` はM_Δへの入場根拠であり、そのベクトルをそのまま `M_B'` 更新量にしない。

Selectionは `retain / reject / defer` を区別する。retainされた関係を valid conditions / break conditions / unresolved items / provenance とともに有限 `M_B'` へ再構成する。

## 7. 鉱山の現行読み

### RDL_Demos

優先採掘:

```text
world / body / perception / relations / dialogue
seeded simulation / simultaneous resolution / richness metrics
finite B / RIB_B
same-frozen M_B comparison
explicit unresolved review
H / θ / M_Δ
T1 reconstruction
finite-context authority / fresh re-entry
```

`LocalLoadVector / ExplorationState / LeapEngine / HVec / XiPool / Boundary` をCore意味へ名前だけで昇格させない。

### RDL_Enterprise

優先採掘:

```text
bounded acquisition
RIBSection
frozen interpretation context
provenance / coverage separation
restart durability
staged commitment / authority
changed-condition acceptance
```

```text
StructuralConflict != E != H
Human Attention != H
coverage metric != ξ
Function != M_B
```

### RDL_Human

HumanはT3仮説鉱山として扱う。Sensitivity、secure-base、relation binding、context-dependent personality、multi-timescale、SFO系仮説等をGameAI-local modelとして試すが、Core primitiveへ昇格させない。

## 8. 実装規律

```text
Observation != Candidate != Commitment != Active
UNKNOWN != UNRESOLVED != NOT_EVALUATED
Authority != Truth
Inspection tool != Selection criterion
```

Context / provenanceには、必要に応じて次を保持する。

```text
tick / time
agent / observer
Purpose / boundary_id
selected dimensions
coverage
perception rule
action
source / subsequent observation ids
active M_B version
relevant history refs
```

新しい型は、現在の破断を再検査するために必要な場合だけ追加する。

## 9. 現行vertical slice

```text
world interaction
→ bounded observation
→ canonical acquisition
→ RIB_B
→ interp(frozen M_B, RIB_B)
→ F
→ action / world change
→ subsequent bounded observation
→ RIB_B'
→ same pre-update M_B
→ F'
→ E
→ finite unresolved review
→ H
→ local maintenance or M_Δ / T1
→ fresh re-entry
→ later behavior change
```

現在実装済みなのは `E` まで。次はfinite assessment / unresolved reviewである。

## 10. GameAI固有のSelection / richness

単一スカラー最大化を避ける。

```text
behavior variety
individual divergence
history dependence
relation dependence
place meaning drift
daily variation
readability
surprise
recoverability
rupture diversity
```

```text
survival ↑ != interestingness ↑
winning ↑  != lifelikeness ↑
randomness ↑ != surprise quality ↑
```

## 11. 感情設計

感情語を基底状態にしない。

```text
finite interaction / interpretation history
+ unresolved provenance when present
+ RelationalHistory
+ RelationConstraint
+ SensitivityProfile
+ BodyState
+ CurrentContext
↓
AffectExpression
ActionBias
DialogueTone
```

`Threat / Opportunity / Control / Recoverability / Novelty` 等はGameAI-local descriptorでありCore primitiveではない。

## 一文圧縮

> **GameAI Labは、更新済みのRDL鉱山を部品庫として使い、Core v2.3の有限 `B / RIB_B / M_B` 境界を崩さず、実際のinteraction chainを有限受入証拠で伸ばす。**
