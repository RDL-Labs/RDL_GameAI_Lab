# RDL_GameAI 設計手法

*CURRENT — Core 3270982 / BASE v2.3 / SPEC v2.4 / dynamic theta explanation / RIB_B準拠*

**責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)を横断する設計・有限検証の規律。
**依存・非責務:** 意味論はCore reference、実装成熟度は[canonical roadmap](../../notes/experiment-roadmap.md)。Layerの細部・生活Phase・神経サブタイプの正本はそれぞれの責務文書に置く。

## 0. 目的

`RDL_GameAI_Lab` は、`RDL_Demos`、`RDL_Enterprise`、`RDL_Human` を素材鉱山として使いながら、意味論は[同期済みCore参照](../semantic-reference/RDL_Core_T0_T1_reference.md)を基準に再検査する。

既存実装のクラス名・変数名・過去語彙は、それだけではCore意味を保証しない。本設計手法自身も有限Boundary上の運用方針であり、自己例外化しない。

## 1. 権威順序

```text
RDL_Core (pinned semantic reference)
  T0 BASE / SPEC
  T1 SILN operations
      ↓ semantic / operational authority

RDL_Demos / RDL_Enterprise / RDL_Human / RDL_General_Modules
      ↓ extraction / translation / organization aid

RDL_GameAI_Lab
  game-specific Purpose / B
  acquisition
  Selection criteria
  experiments
  implementations
```

`RDL_General_Modules` の Layering は整理補助であり、Core semantic authorityではない。

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

### RDL_General_Modules

`RDL 横断レイヤリング・キット` を、複数のGameAI-local状態を時間スケールや拘束伝播で整理する補助Viewとして使う。

```text
Layer Profile
!= Core primitive
!= canonical M_B decomposition
!= runtime authority
```

## 8. 実装規律

semantic fallibility allowed / structural integrity required。誤認・誤一般化・誤接続・語彙誤伝播はlocal候補として許容するが、履歴破損・参照破損・provenance消失・canonical authority混同を意図した動作として扱わない。sleep != T1、Player statement != World Truthを維持する。

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

以下は将来のformation / re-entryを含む参照経路。現行のactionはcanonical Fから駆動されず、独立したGameAI-local policyが所有する。H以降のT1経路は未実装。

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

現在は `E → explicit finite review → H → retained H` までdiagnosticとして実装済み。raw Eの `E-only-not-reviewed` は別レコードのreview状態とは独立である。Experience・fixed Sensitivity・Body・Realtimeは最小operational、Expressionは行動決定後の派生表示。θ / M_Δ / T1 / canonical action authorityは未実装。

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
+ derived sensitivity (planned Neural Dynamics output)
+ BodyState
+ CurrentContext
↓
AffectExpression
ActionBias
DialogueTone
```

`Threat / Opportunity / Control / Recoverability / Novelty` 等はGameAI-local descriptorでありCore primitiveではない。

## 12. NPC レイヤリング Profile

GameAI-localな要素を、実装上の更新速度・保持時間・拘束伝播で次のように整理する。

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

対応候補：

```text
Generation / DNA
= seeded generation constraints / future inheritance range

Neural Dynamics
= neural baseline / dynamic state / derived sensitivity (planned)

Physical / Body
= BodyState

Experience / Relation History
= InteractionHistoryRecord / RelationHistory / relation constraints

Realtime / Current Context
= current bounded situation / current action / short-term context
```

ただし、各LayerをCore `M_B`へ自動同一視しない。Layerはrelation provenance / update tempo / retentionを整理するViewであり、`M_B` の5つの排他的fieldではない。

```text
SensitivityProfile != M_B by identity
BodyState          != M_B by identity
RelationHistory    != M_B by identity
CurrentContext     != M_B by identity
```

```text
owner module / store != M_B by identity
finite currently adopted agent-side relations / parameters ⊂ M_B
semantic eligibility != current operational admission
```

raw observationは基本的に `RIB_B` 側へ入り、current priority・action commitment・retained learned relation等が個体側拘束として採用された場合だけ `M_B` participantになり得る。同一F/F'比較中はpre-update `M_B` を凍結する。

現段階ではExperience・fixed Sensitivity・Bodyの有限なaction influenceを契約下で実装済み。canonical sidecarにはaction / graph mutation authorityを与えない。次は[層間分離の検証](../experiment-contracts/CROSS_LAYER_separation_contract.md)を固定し、T1の形成契約を別途設計する。

以下は局所sliceの採用順の参照であり、一本のcanonical経路や生活Phaseではない。現在の固定retry profileは神経値から導出されたものではない。

```text
finite assessment / H
→ Experience / Relation History
→ Neural Dynamics + Affect
→ reviewed cross-layer influence
→ later T1 / authority work
```

Generation / DNA と reproduction は、現在のcutoverには不要なので deferred とする。

Layer Profileが局所的に完成しても、

```text
Complete_B(NPC Layer Profile) = true
and
ξ(B) != 0
```

を維持する。

## 一文圧縮

> **GameAI Labは、RDL鉱山を部品庫として使い、同期済みCoreの有限 `B / RIB_B / M_B` 境界を崩さず、GameAI-localな状態を必要に応じてレイヤリングしながら、実際のinteraction chainを有限受入証拠で伸ばす。**
